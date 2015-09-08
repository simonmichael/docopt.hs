{-# LANGUAGE FlexibleInstances #-}
module LangAgnosticTests where

import Control.Monad (forM, unless)
import System.Exit
import System.Console.ANSI

import System.Console.Docopt
import System.Console.Docopt.Types
import System.Console.Docopt.ParseUtils
import System.Console.Docopt.UsageParse (pDocopt)
import System.Console.Docopt.OptParse (getArguments)

import           Data.Map (Map)
import qualified Data.Map as M

import Data.List.Split
import Data.Aeson
import qualified Data.ByteString.Lazy.Char8 as BS

import Distribution.TestSuite


instance ToJSON ArgValue where
  toJSON x = case x of
    MultiValue vs -> toJSON $ reverse vs
    Value v       -> toJSON v
    NoValue       -> toJSON Null
    Counted n     -> toJSON n
    Present       -> toJSON True
    NotPresent    -> toJSON False

instance ToJSON (Map Option ArgValue) where
  toJSON argmap =
    let argmap' = M.mapKeys humanize argmap
    in  toJSON argmap'

coloredString :: Color -> String -> String
coloredString c str = setSGRCode [SetColor Foreground Dull c]
                    ++ str
                    ++ setSGRCode [Reset]

green, red, yellow, blue, magenta :: String -> String
green   = coloredString Green
red     = coloredString Red
yellow  = coloredString Yellow
blue    = coloredString Blue
magenta = coloredString Magenta


tests :: IO [Test]
tests = readFile "test/testcases.docopt" >>= testsFromDocoptSpecFile "testcases.docopt"


testsFromDocoptSpecFile :: String -> String -> IO [Test]
testsFromDocoptSpecFile name testFile =
  let notCommentLine x = null x || ('#' /= head x)
      testFileClean = unlines $ filter notCommentLine $ lines testFile
      caseGroups = filter (not . null) $ splitOn "r\"\"\"" testFileClean

  in
  return . (:[]) . testGroup name $ (zip caseGroups [1..]) >>= \(caseGroup, icg) -> do

    let [usage, rawCases] = splitOn "\"\"\"" caseGroup
        cases = filter (/= "\n") $ splitOn "$ " rawCases

    let (optFormat, docParseMsg) = case runParser pDocopt M.empty "Usage" usage of
          Left e -> ((Sequence [], M.empty), "Couldn't parse usage text")
          Right o -> (o, "")

    let groupDescLines = [
            docParseMsg,
            "Docopt:",
            blue usage,
            "Pattern:",
            magenta (show optFormat)
          ]

    (zip cases [1..]) >>= \(testcase, itc) -> do

      let (cmdline, rawTarget_) = break (== '\n') testcase
          rawTarget = filter (/= '\n') rawTarget_
          maybeTargetJSON = decode (BS.pack rawTarget) :: Maybe Value
          rawArgs = tail $ words cmdline

      let (parsedArgs, argParseMsg) = case getArguments optFormat rawArgs of
            Left e -> (M.empty, "Parse Error: " ++ red (show e) ++ "\n")
            Right a -> (a, "")

      let parsedArgsJSON = toJSON parsedArgs
          testCaseSuccess = if rawTarget == "\"user-error\""
            then M.null parsedArgs
            else maybeTargetJSON == Just parsedArgsJSON

      let testDescLines = [
              "Cmd: " ++ yellow cmdline,
              "Target: " ++ (if testCaseSuccess then green else magenta) rawTarget
            ]
      -- unless testCaseSuccess $
      --   putStrLn $ "Failure: " ++ red (BS.unpack $ encode parsedArgsJSON)
      -- putStrLn ""

      let ti = TestInstance
                { run = return . Finished $
                      (if testCaseSuccess then Pass else
                          Fail $ unlines . filter (not . null) $
                            groupDescLines
                            ++ testDescLines
                            ++ ["Failure: " ++ red (BS.unpack $ encode parsedArgsJSON)])
                , name = "group-" ++ show icg ++ "-case-" ++ show itc
                , tags = []
                , options = []
                , setOption = \_ _ -> Right ti
                }

      return $ Test ti
