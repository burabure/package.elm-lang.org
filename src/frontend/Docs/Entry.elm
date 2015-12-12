module Docs.Entry where

import Effects as Fx exposing (Effects)
import Html exposing (..)
import Html.Attributes exposing (..)
import Regex
import String

import Docs.Name as Name
import Docs.Type as Type exposing (Type)
import Utils.Code exposing (arrow, colon, equals, keyword, padded, space)
import Utils.Markdown as Markdown



-- MODEL


type alias Model tipe =
    { name : String
    , info : Info tipe
    , docs : String
    }


type Info tipe
    = Value tipe (Maybe Fixity)
    | Union (UnionInfo tipe)
    | Alias (AliasInfo tipe)


type alias UnionInfo tipe =
    { vars : List String
    , tags : List (Tag tipe)
    }


type alias Tag tipe =
    { tag : String
    , args : List tipe
    }


type alias AliasInfo tipe =
    { vars : List String
    , tipe : tipe
    }


type alias Fixity =
    { precedence : Int
    , associativity : String
    }



-- UPDATE


update : a -> Model tipe -> (Model tipe, Effects a)
update action model =
  (model, Fx.none)



-- MAP


map : (a -> b) -> Model a -> Model b
map func model =
  let
    newInfo =
      case model.info of
        Value tipe fixity ->
          Value (func tipe) fixity

        Union {vars,tags} ->
          Union (UnionInfo vars (List.map (tagMap func) tags))

        Alias {vars,tipe} ->
          Alias (AliasInfo vars (func tipe))
  in
    { model | info = newInfo }


tagMap : (a -> b) -> Tag a -> Tag b
tagMap func tag =
  { tag | args = List.map func tag.args }



-- STRING VIEW


stringView : Model String -> Html
stringView model =
  let
    annotation =
      case model.info of
        Value tipe _ ->
            [ nameToLink model.name :: padded colon ++ [text tipe] ]

        Union {vars,tags} ->
            unionAnnotation True (\t -> [text t]) model.name vars tags

        Alias {vars,tipe} ->
            [ aliasNameLine model.name vars
            , [ text "    ", text tipe ]
            ]
  in
    div [ class "docs-entry", id model.name ]
      [ annotationBlock annotation
      , div [class "docs-comment"] [Markdown.block model.docs]
      ]



-- TYPE VIEW


(=>) = (,)


typeView : Name.Dictionary -> Name.Context -> Model Type -> Html
typeView nameDict docsContext model =
  div [ class "docs-entry", id model.name ]
    [ annotationBlock (viewTypeAnnotation True nameDict docsContext model)
    , div [class "docs-comment"] [Markdown.block model.docs]
    ]


viewTypeAnnotation : Bool -> Name.Dictionary -> Name.Context -> Model Type -> List (List Html)
viewTypeAnnotation isNormal nameDict docsContext model =
  case model.info of
    Value tipe _ ->
      valueAnnotation isNormal nameDict docsContext model.name tipe

    Union {vars,tags} ->
      unionAnnotation isNormal (Type.toHtml nameDict docsContext Type.App) model.name vars tags

    Alias {vars,tipe} ->
      aliasAnnotation isNormal nameDict docsContext model.name vars tipe


annotationBlock : List (List Html) -> Html
annotationBlock bits =
  div
    [ class "formatted-code"
    , style ["padding" => "10px 0"]
    ]
    (List.concat (List.intersperse [text "\n"] bits))


nameToLink : String -> Html
nameToLink name =
  let
    humanName =
      if Regex.contains operator name then
        "(" ++ name ++ ")"

      else
        name
  in
    a [style ["font-weight" => "bold"], href ("#" ++ name)] [text humanName]


operator : Regex.Regex
operator =
  Regex.regex "^[^a-zA-Z0-9]+$"



-- VALUE ANNOTATIONS


valueAnnotation : Bool -> Name.Dictionary -> Name.Context -> String -> Type -> List (List Html)
valueAnnotation isNormal nameDict docsContext name tipe =
  let
    nameHtml =
      if isNormal then
        nameToLink name

      else
        text name

    maxLength =
      if isNormal then 64 else 88
  in
    case tipe of
      Type.Function args result ->
          if String.length name + 3 + Type.length Type.Other tipe > maxLength then
            [ nameHtml ] :: longFunctionAnnotation nameDict docsContext args result

          else
            [ nameHtml :: padded colon ++ Type.toHtml nameDict docsContext Type.Other tipe ]

      _ ->
        [ nameHtml :: padded colon ++ Type.toHtml nameDict docsContext Type.Other tipe ]


longFunctionAnnotation : Name.Dictionary -> Name.Context -> List Type -> Type -> List (List Html)
longFunctionAnnotation nameDict docsContext args result =
  let
    tipeHtml =
      List.map (Type.toHtml nameDict docsContext Type.Func) (args ++ [result])

    starters =
      [ text "    ", colon, text "  " ]
      ::
      List.repeat (List.length args) [ text "    ", arrow, space ]
  in
    List.map2 (++) starters tipeHtml



-- UNION ANNOTATIONS


unionAnnotation : Bool -> (tipe -> List Html) -> String -> List String -> List (Tag tipe) -> List (List Html)
unionAnnotation isNormal tipeToHtml name vars tags =
  let
    nameLine =
      if isNormal then
        [ keyword "type"
        , space
        , nameToLink name
        , text (String.concat (List.map ((++) " ") vars))
        ]

      else
        [ text <| "type " ++ name ++ String.concat (List.map ((++) " ") vars)
        ]

    tagLines =
      List.map2 (::)
        (text "    = " :: List.repeat (List.length tags - 1) (text "    | "))
        (List.map (viewTag tipeToHtml) tags)
  in
    nameLine :: tagLines


viewTag : (tipe -> List Html) -> Tag tipe -> List Html
viewTag tipeToHtml {tag,args} =
  text tag :: List.concatMap ((::) space) (List.map tipeToHtml args)



-- ALIAS ANNOTATIONS


aliasAnnotation : Bool -> Name.Dictionary -> Name.Context -> String -> List String -> Type -> List (List Html)
aliasAnnotation isNormal nameDict docsContext name vars tipe =
  let
    typeLines =
      case tipe of
        Type.Record fields ext ->
            let
              (firstLine, starters) =
                  case ext of
                    Nothing ->
                      ( []
                      , text "    { " :: List.repeat (List.length fields) (text "    , ")
                      )

                    Just extName ->
                      ( [ [ text "    { ", text extName, text " |" ] ]
                      , text "      | " :: List.repeat (List.length fields) (text "      , ")
                      )
            in
              firstLine
              ++ List.map2 (::) starters (List.map (Type.fieldToHtml nameDict docsContext) fields)
              ++ [[text "    }"]]

        _ ->
            [ text "    " :: Type.toHtml nameDict docsContext Type.Other tipe ]

    nameLine =
      if isNormal then
        aliasNameLine name vars
      else
        [ text <| "type alias " ++ name ++ String.concat (List.map ((++) " ") vars) ++ " = "
        ]
  in
    nameLine :: typeLines


aliasNameLine : String -> List String -> List Html
aliasNameLine name vars =
  [ keyword "type"
  , space
  , keyword "alias"
  , space
  , nameToLink name
  , text (String.concat (List.map ((++) " ") vars))
  , space
  , equals
  , space
  ]
