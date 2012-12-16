
module Parser where

import Text.ParserCombinators.Parsec
import Data.Functor
import Data.Char (digitToInt)
import Data.List

-- Output data structure
data FFILine = PlainLine String
          | FFILine {
            jsExp :: JSExpr,
            hsName :: String,
            args :: [Argument],
            retVal :: ReturnValue
            }
            
data Argument = StringArgument | OtherArgument String deriving (Eq)
data ReturnValue = IOVoid | IOReturn String | PureReturn String deriving (Eq)

isIORetVal :: ReturnValue -> Bool
isIORetVal (PureReturn _) = False
isIORetVal _ = True

type JSExpr = [JSExprPart]
data JSExprPart = StringPart String | ArgumentPart Int | RestArgPart

parseFFIFile :: GenParser Char st [FFILine]
parseFFIFile = endBy line eol
 
line :: GenParser Char st FFILine
line = ffiLine <|> plainLine

plainLine :: GenParser Char st FFILine
plainLine = PlainLine <$> many anyChar

whiteSpaces :: GenParser Char st String
whiteSpaces = many $ (char ' ' <|> char '\t')

ffiLine :: GenParser Char st FFILine
ffiLine = do
  string "foreign "
  whiteSpaces
  string "import "
  whiteSpaces
  string "jscall "
  whiteSpaces
  char '\"'
  jsExpr <- jsExpr
  char '\"'
  hsName <- many alphaNum
  whiteSpaces
  string "::"
  whiteSpaces
  arg <- arguments
  ret <- returnValue
  return $ FFILine jsExpr hsName arg ret 

jsExpr :: GenParser Char st JSExpr
jsExpr = many jsExprPart

jsExprPart :: GenParser Char st JSExprPart
jsExprPart = jsExprArgPart <|> jsExprRestArgPart <|> jsExprStringPart

positiveNatural :: GenParser Char st Int
positiveNatural = 
    foldl' (\a i -> a * 10 + digitToInt i) 0 <$> many1 digit

jsExprArgPart :: GenParser Char st JSExprPart
jsExprArgPart = do
  char '%'
  n <- positiveNatural
  return $ ArgumentPart n
  
jsExprRestArgPart :: GenParser Char st JSExprPart
jsExprRestArgPart = string "%*" >> return RestArgPart

jsExprStringPart :: GenParser Char st JSExprPart
jsExprStringPart = StringPart <$> many (noneOf "%")
 
arguments :: GenParser Char st [Argument]
arguments = endBy argument (string "->")

argument :: GenParser Char st Argument
argument = stringArgument <|> plainArgument

stringArgument :: GenParser Char st Argument
stringArgument = do
  whiteSpaces
  string "String"
  whiteSpaces
  return StringArgument

plainArgument :: GenParser Char st Argument
plainArgument = do
  whiteSpaces
  res <- many alphaNum
  whiteSpaces
  return $ OtherArgument res 


returnValue :: GenParser Char st ReturnValue
returnValue = ioVoid <|> ioReturnValue <|> pureReturnValue

ioVoid :: GenParser Char st ReturnValue
ioVoid = do
  whiteSpaces
  string "IO"
  whiteSpaces
  string "()"
  whiteSpaces
  return IOVoid 

ioReturnValue :: GenParser Char st ReturnValue
ioReturnValue = do
  whiteSpaces
  string "IO"
  whiteSpaces
  t <- many alphaNum
  whiteSpaces
  return $ IOReturn t
  
pureReturnValue :: GenParser Char st ReturnValue
pureReturnValue = do
  whiteSpaces
  t <- many alphaNum
  whiteSpaces
  return $ PureReturn t

eol = char '\n'