
module Printer where

import Parser

haskellFile :: [FFILine] -> String
haskellFile = concat . map haskellLine

haskellLine :: FFILine -> String
haskellLine (PlainLine s) = s ++ "\n"

haskellLine (FFILine jsExp hsName hsType) =
  if needsConversion hsType then
    --expression with something that needs conversion
    "foreign import ccall \"" ++ hsName ++ "JSImpl\" " ++ hsName ++ "JSStr :: " ++ signature
    ++ "\n" ++ hsName ++ (argumentList (length $ args hsType)) ++ " = " ++ hsName ++ "JSImpl " ++ (concat . map showArg $ zip (args hsType) [1..] ) ++ "\n"
  else
    --expression without strings
    "foreign import ccall \"" ++ hsName ++ "JSImpl\" " ++ hsName ++ " :: " ++ signature ++ "\n"
  where
    needsConversion t = case t of
        (IOType t')        -> needsConversion t'
        StringType         -> True
        (FunctionType a r) -> argNeedsConversion a || needsConversion r
        _                  -> False
    argNeedsConversion t = case t of
        StringType         -> True
        IOVoid             -> True
        (IOType _)         -> True
        (FunctionType _ _) -> True
        _                  -> False
    
      
      
    showArg :: (Type,Int) -> String
    showArg (a,i) = case a of
                      StringType       -> "(toJs a" ++ (show i) ++ ") "
                      FunctionType _ _ -> "(JSFun a" ++ (show i) ++") "
                      _                -> "a" ++ (show i) ++ " "
  
    argTypeList = concat . map (\a-> showArgType a ++ " -> ") $ args hsType
    signature = argTypeList ++ (showArgType . result $ hsType)
    showArgType :: Type -> String
    showArgType StringType = "JSString"
    showArgType IOVoid = "IO ()"
    showArgType (IOType t) = "IO (" ++ showArgType t ++ ")"
    showArgType (PlainType s) = s
    showArgType (FunctionType f r) = "(" ++ (showArgType f) ++ " -> " ++ (showArgType r) ++ ")"
    
    argumentList :: Int -> String
    argumentList max = concat . map (\i -> " a" ++ (show i)) $ [1..max]


javascriptFile :: [FFILine] -> String
javascriptFile = concat . map javascriptLine

javascriptLine (PlainLine _) = ""
javascriptLine (FFILine jsExp hsName hsType) =
  "function " ++ hsName ++ "JSImpl(" ++ (argumentList $ length (args hsType)) ++ ioArg ++ ") {\n  "
  ++ if (result hsType) == IOVoid then jsCommand ++ ";\n  return [1,0];\n}" else "  return [1,0," ++ jsCommand ++ "];\n}\n"
  where
    argumentList :: Int -> String
    argumentList max = concatWith "," . map (\i -> "a" ++ (show i)) $ [1..max]
    concatWith :: String -> [String] -> String
    concatWith sep (x:y:xs) = x ++ sep ++ (concatWith sep (y:xs))
    concatWith _ (x:[])     = x
    concatWith _  _ = ""
    ioArg = if isIORetVal then
              if null (args hsType) then
                "_"
              else  ",_"
            else ""
    isIORetVal = case result hsType of
      IOVoid   -> True
      IOType _ -> True
      _        -> False
    jsCommand = concat . map showExprPart $ jsExp
    showExprPart :: JSExprPart -> String
    showExprPart (StringPart s) = s
    showExprPart (ArgumentPart i) = "a" ++ (show i)
    showExprPart (RestArgPart) = concatWith "," . map showExprPart $ restArguments
    restArguments :: [JSExprPart]
    restArguments = let argId (ArgumentPart i) = i
                        argId _ = 0
                        highestArgument = maximum . map (argId) $ jsExp
                        numArguments = length (args hsType)
                        missingArgs = if highestArgument >= numArguments then [] else [(highestArgument+1) .. numArguments]
                    in map (\i -> ArgumentPart i) missingArgs

-- helper functions
args :: Type -> [Type]
args t = case t of 
  FunctionType a r -> a:(args r)
  _                -> []
  
result :: Type -> Type
result t = case t of
  FunctionType a r -> result r
  r                -> r