module Component.PackagePreview where

import Dict
import Set
import Effects as Fx
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Json exposing ((:=))

import Component.PackageDocs as PDocs
import Docs.Package as Docs
import Parse.Type as Type
import Utils.Markdown as Markdown
import Utils.Path as Path



-- MODEL


type Model
    = AwaitingFile
    | BadFile (Maybe String)
    | GoodFile (Dict.Dict String (Docs.Module String)) PDocs.Model


init : (Model, Fx.Effects Action)
init =
  ( AwaitingFile
  , Fx.none
  )



-- UPDATE


type Action
    = NoOp
    | Fail (Maybe String)
    | LoadDocs (Dict.Dict String (Docs.Module String))
    | SwitchTo String


update : Action -> Model -> ( Model, Fx.Effects Action )
update action model =
  flip (,) Fx.none <|
  case action of
    NoOp ->
      model

    Fail maybeMsg ->
      BadFile maybeMsg

    LoadDocs docs ->
      case List.head (Dict.keys docs) of
        Nothing ->
          BadFile (Just "The JSON you uploaded does not have any modules in it!")

        Just moduleName ->
          GoodFile docs (docsForModule moduleName docs)

    SwitchTo moduleName ->
      case model of
        GoodFile docs _ ->
          GoodFile docs (docsForModule moduleName docs)

        _ ->
          model



-- VIEW


(=>) = (,)


view : Signal.Address Action -> Model -> List Html
view address model =
  case model of
    AwaitingFile ->
      [ instructions long
      ]

    BadFile maybeMsg ->
      let
        errorMsg =
          case maybeMsg of
            Just msg ->
              "Problem uploading that file: " ++ msg

            Nothing ->
              "Problem uploading that file, try it a different way."
      in
        [ instructions long
        , p [ style [ "color" => "red" ] ] [ text errorMsg ]
        ]

    GoodFile docs docsModel ->
      [ instructions short
      , div
          [ style
              [ "border-top" => "1px solid #eeeeee"
              , "margin-top" => "1em"
              ]
          ]
          [ PDocs.view (Signal.forwardTo address (\_ -> Debug.crash "TODO")) docsModel
          , viewSidebar address (Dict.keys docs)
          ]
      ]


viewSidebar : Signal.Address Action -> List String -> Html
viewSidebar address modulesNames =
  div [ class "pkg-nav" ]
    [ ul
      [ class "pkg-nav-value" ]
      (moduleLinks address modulesNames)
    ]


moduleLinks : Signal.Address Action -> List String -> List Html
moduleLinks address modulesNames =
  let
    moduleItem moduleName =
      li [] [ moduleLink address moduleName ]
  in
    List.map moduleItem modulesNames


moduleLink : Signal.Address Action -> String -> Html
moduleLink address moduleName =
  a
    [ onClick address (SwitchTo moduleName)
    , class "pkg-nav-module"
    , href ("#" ++ Path.hyphenate moduleName)
    ]
    [ text moduleName ]



-- DOCS FUNCTIONS


docsForModule : String -> Dict.Dict String (Docs.Module String) -> PDocs.Model
docsForModule moduleName docs =
  case Dict.get moduleName docs of
    Just moduleDocs ->
      let
        docsContext =
          case (Dict.get moduleName docs) of
            Just modul ->
              { current = moduleName
              , available = Set.fromList (Dict.keys modul.entries)
              }

            _ ->
              { current = moduleName
              , available = Set.empty
              }

      in
      PDocs.toChunks moduleDocs
        |> List.map (PDocs.chunkMap Type.parseWithFallback)
        |> PDocs.Info moduleName (PDocs.toNameDict docs)
        |> flip (,) docsContext
        |> PDocs.ParsedDocs

    Nothing ->
      PDocs.Loading



-- VIEW INSTRUCTIONS


instructions : String -> Html
instructions md =
  div
    [ style [ "width" => "600px" ]
    ]
    [ Markdown.block md
    , input
        [ type' "file"
        , id "fileLoader"
        , style [ "margin-left" => "1em" ]
        ]
        []
    ]


long : String
long = """

# Preview your Docs

To generate documentation for your package, run this command in the root of
your package:

```bash
elm make --docs=documentation.json
```

That will create a file called `documentation.json`. Give me that file.

"""


short : String
short = """

# Preview your Docs

"""
