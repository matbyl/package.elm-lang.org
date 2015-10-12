module Component.Module where

import Debug
import Dict
import Graphics.Element exposing (..)
import Markdown
import Regex
import String
import Text

import ColorScheme as C
import Component.Documentation as D
import Component.Header as Header


view : Signal.Address String -> Int -> String -> String -> String -> List String -> List String -> List (String, String) -> D.Documentation -> Element
view versionAddr innerWidth user package version versionList modules mentionedTypes docs =
    flow down
    [ Header.view versionAddr innerWidth user package version versionList (Just docs.name)
    , color C.lightGrey (spacer innerWidth 1)
    , spacer innerWidth 12
    , viewDocs innerWidth (D.toDocDict modules mentionedTypes docs) docs.comment
    ]


viewDocs : Int -> D.DocDict -> String  -> Element
viewDocs innerWidth documentation comment =
  case String.split "\n@docs " comment of
    [] ->
        Debug.crash "invalid module docs, no @docs declarations"

    prose :: chunks ->
        let
          varProsePairs : List (List String, String)
          varProsePairs =
            List.map extractVars chunks
        in
          flow down <|
            viewProse innerWidth prose
            :: List.concatMap (viewPair innerWidth documentation) varProsePairs


extractVars : String -> (List String, String)
extractVars rawChunk =
  let chunk = String.trimLeft rawChunk
  in
      case String.uncons chunk of
        Nothing ->
          ([], "")

        Just (c, subchunk) ->
            if D.isVarChar c then

                let
                  (var, rest) = takeWhile D.isVarChar chunk
                  (vars, nextChunk) = extractCommaThenVars rest
                in
                  (var :: vars, nextChunk)

            else

                let
                  (op, rest) = takeWhile ((/=) ')') subchunk
                  (vars, nextChunk) = extractCommaThenVars (String.dropLeft 1 rest)
                in
                  (op :: vars, nextChunk)


extractCommaThenVars : String -> (List String, String)
extractCommaThenVars rawChunk =
  let chunk = String.trimLeft rawChunk
  in
      case String.uncons chunk of
        Just (',', subchunk) ->
          extractVars subchunk

        _ -> ([], chunk)


takeWhile : (Char -> Bool) -> String -> (String, String)
takeWhile pred chunk =
  case String.uncons chunk of
    Nothing ->
        ("", "")

    Just (c, rest) ->
        if pred c then

            let
              (result, chunk') = takeWhile pred rest
            in
              (String.cons c result, chunk')

        else
            ("", chunk)


docsPattern : Regex.Regex
docsPattern =
    Regex.regex "(.*)\n@docs\\s+([a-zA-Z0-9_']+(?:,\\s*[a-zA-Z0-9_']+)*)"


viewPair : Int -> D.DocDict -> (List String, String) -> List Element
viewPair innerWidth documentation (vars, prose) =
    List.map (viewVar innerWidth documentation) vars
    ++ [viewProse innerWidth prose]


viewProse : Int -> String -> Element
viewProse innerWidth prose =
    width innerWidth (Markdown.toElementWith D.options prose)


viewVar : Int -> D.DocDict -> String -> Element
viewVar innerWidth documentation var =
    case Dict.get var documentation of
      Nothing ->
        let msg =
              Text.concat
              [ Text.fromString "There is some problem with the docs for '"
              , Text.monospace (Text.fromString var)
              , Text.fromString "', please inform the package author."
              ]
        in
            width innerWidth (leftAligned msg)

      Just entry ->
        D.viewEntry innerWidth var entry