module Docs.Name where

import Dict
import Html exposing (..)
import Html.Attributes exposing (..)
import Set
import String


type alias Canonical =
    { home : String
    , name : String
    }


type alias Dictionary =
    Dict.Dict String (Set.Set String)


type alias Context =
    { current : String
    , available : Set.Set String
    }


toLink : Context -> Canonical -> Html
toLink ctx ({home,name} as canonical) =
  if Set.member name ctx.available then
    let
      link =
        (anchorContext ctx home) ++ name
          |> parseLink

    in
      a [href link] [text name]

  else
    text (qualifiedType canonical)


parseLink : String -> String
parseLink link =
  String.map (\c -> if c == '.' then '-' else c) link


anchorContext : Context -> String -> String
anchorContext {current} home =
  if home == current then
    "#"
  else
    home ++ "#"


qualifiedType : Canonical -> String
qualifiedType {home, name} =
  if String.isEmpty home then
    name
  else
    home ++ "." ++ name

nameToString : Canonical -> String
nameToString {home, name} =
  home ++ "." ++ name
