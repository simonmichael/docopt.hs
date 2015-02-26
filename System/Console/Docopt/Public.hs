module System.Console.Docopt.Public
  (
    -- * Parsed usage string
      Docopt ()
    , usage
    , exitWithUsage

    -- * Argument lookup
    , Option()
    , Arguments()

    -- ** Query functions
    , isPresent
    , notPresent
    , getArg
    , getArgWithDefault
    , getAllArgs
    , getArgCount

    -- ** 'Option' constructors
    , command
    , argument
    , shortOption
    , longOption

    -- ** Deprecated
    , getAllArgsM
    , notPresentM
    , isPresentM
    , getFirstArg

    -- ** Re-exported from Parsec
    , ParseError
  )
  where

import System.Exit

import Data.Map as M hiding (null)
import System.Console.Docopt.Types
import System.Console.Docopt.ApplicativeParsec (ParseError)


-- | Exit with help message.
exitWithUsage :: Docopt -> IO a
exitWithUsage doc = do
  putStr $ usage doc
  exitFailure

-- Query functions
------------------

isPresent :: Arguments -> Option -> Bool
isPresent args opt =
  case opt `M.lookup` args of
    Nothing  -> False
    Just val -> case val of
      NoValue    -> False
      NotPresent -> False
      _          -> True

notPresent :: Arguments -> Option -> Bool
notPresent args o = not $ isPresent args o

getArg :: Monad m => Arguments -> Option -> m String
getArg args opt =
  let failure = fail $ "no argument given: " ++ show opt
  in  case opt `M.lookup` args of
        Nothing  -> failure
        Just val -> case val of
          MultiValue (v:_) -> return v
          Value v           -> return v
          _                 -> failure

getArgWithDefault :: Arguments -> String -> Option -> String
getArgWithDefault args def opt =
  case args `getArg` opt of
    Just val -> val
    Nothing -> def

getAllArgs :: Arguments -> Option -> [String]
getAllArgs args opt =
  case opt `M.lookup` args of
    Nothing  -> []
    Just val -> case val of
      MultiValue vs -> reverse vs
      Value v       -> [v]
      _             -> []

getArgCount :: Arguments -> Option -> Int
getArgCount args opt =
  case opt `M.lookup` args of
    Nothing -> 0
    Just val -> case val of
      Counted i     -> i
      MultiValue vs -> length vs
      Value _       -> 1
      Present       -> 1
      _             -> 0


-- Option constructors
----------------------

command :: String -> Option
command s = Command s

argument :: String -> Option
argument s = Argument s

shortOption :: Char -> Option
shortOption c = ShortOption c

longOption :: String -> Option
longOption s = LongOption s

-- Deprecated
-------------

{-# DEPRECATED getAllArgsM "Monadic query functions will soon be removed" #-}
getAllArgsM :: Monad m => Arguments -> Option -> m [String]
getAllArgsM o e = return $ getAllArgs o e

{-# DEPRECATED notPresentM "Monadic query functions will soon be removed" #-}
notPresentM :: Monad m => Arguments -> Option -> m Bool
notPresentM args o = return $ not $ isPresent args o

{-# DEPRECATED isPresentM "Monadic query functions will soon be removed" #-}
isPresentM :: Monad m => Arguments -> Option -> m Bool
isPresentM args o = return $ isPresent args o

{-# DEPRECATED getFirstArg "Use 'getAllArgs' instead" #-}
getFirstArg :: Monad m => Arguments -> Option -> m String
getFirstArg args opt =
  let failure = fail $ "no argument given: " ++ show opt
  in  case opt `M.lookup` args of
        Nothing  -> failure
        Just val -> case val of
          MultiValue vs -> if null vs then failure else return $ last vs
          Value v       -> return v
          _             -> failure
