module Phagelude
    ( phagelude
    ) where

import Ast
import Err
import Val
import SymTab
import Interpreter
import Data.Map
import Data.Maybe
import Data.Monoid
import Control.Monad.Trans.Except

newTab :: [(String, PhageVal)] -> SymTab PhageVal -> SymTab PhageVal
newTab vs tab = Prelude.foldl (\m (k, v) -> insert k v m) tab vs

typeMess :: Integer -> String -> PhageVal -> PhageErr
typeMess n exp val = "Parameter " ++ show n ++ " has the wrong type,\
    \ expecting '" ++ exp ++ "' but got '" ++ typeName val ++ "'"

arityMess :: Int -> Int -> PhageErr
arityMess a b = show a <> " arguments applied to function of arity " <> show b

-- create a binary function over phage values
createBinFunc ::
    ((PhageVal -> Maybe a), String)
    -> ((PhageVal -> Maybe b), String)
    -> (c -> PhageVal)
    -> (a -> b -> c)
    -> (PhageVal)
createBinFunc (fromA, aStr) (fromB, bStr) toC fn = mkFunc 2 nf
    where
        nf :: PhageFunc
        nf [a, b] tab = case (fromA a, fromB b) of
            (Nothing, _) -> throwE $ typeMess 1 aStr a
            (_, Nothing) -> throwE $ typeMess 2 bStr b
            (Just a, Just b) -> return (toC $ fn a b, tab)
        nf l _ = throwE $ arityMess 2 (length l)

fromNum :: (PhageVal -> Maybe Integer)
fromNum (PNum a) = Just a
fromNum _ = Nothing

fromNumTup = (fromNum, "Number")

mapSnd :: (a -> b) -> (c, a) -> (c, b)
mapSnd fn (a, b) = (a, fn b)

createOnTwoInts = createBinFunc fromNumTup fromNumTup

mkFunc :: Int -> PhageFunc -> PhageVal
mkFunc arity = PFunc arity [] mempty

mkForm :: Int -> PhageForm -> PhageVal
mkForm arity = PForm arity

truthy :: PhageVal -> Bool
truthy (PList []) = False
truthy (PBool a) = a
truthy (PNum 0) = False
truthy (PAtom "") = False
truthy _ = True

arith :: [(String, PhageVal)]
arith =
    fmap (mapSnd (createOnTwoInts PNum))
        [ ("+", (+))
        , ("-", (-))
        , ("*", (*))
        , ("/", div)
        , ("%", mod)
        , ("min", min)
        , ("max", max)
        ]

comparison :: [(String, PhageVal)]
comparison =
    fmap (mapSnd (createOnTwoInts PBool))
        [ ("=", (==))
        , ("<", (<))
        , (">", (>))
        , ("<=", (<=))
        , (">=", (>=))
        ]

consts :: [(String, PhageVal)]
consts =
    [ ("zero", PNum 0)
    , ("true", PBool True)
    , ("false", PBool False)
    ]

specials :: [(String, PhageVal)]
specials =
    [ ("if", mkForm 3 ifFunc)
    , ("cond", mkForm 0 condFunc)
    , ("\\", mkForm 2 funcFunc)
    ] where
        param (AAtom str) = ExceptT $ return $ Right str
        param thing = throwE $ "Invalid parameter name: " <> show thing

        funcFunc :: PhageForm
        funcFunc (AList atoms : block : []) tab = mapM param atoms
            >>= \strs-> ExceptT $ return $ Right
                (PFunc (length strs) [] tab (runFunc strs), tab)
                where
                    runFunc :: [String] -> PhageFunc
                    runFunc strs params oldtab =
                        let tab = newTab (zip strs params) oldtab in
                            eval tab block

        condFunc :: PhageForm
        condFunc [] tab = ExceptT $ return $ Left "Condition not met"
        condFunc (AList (pred : val : []) : nodes) tab = eval tab pred
            >>= \(pred, t) -> if truthy pred
                then eval tab val
                else condFunc nodes tab
        condFunc _ _ = throwE $ "Unrecognized form in call to <cond>"

        ifFunc :: PhageForm
        ifFunc [a, b, c] tab
            =   eval tab a
            >>= \(pred, t) -> eval tab $ if truthy pred then b else c
        ifFunc l _ = throwE $ arityMess 3 (length l)

allVals :: [(String, PhageVal)]
allVals = concat
    [ arith
    , comparison
    , consts
    , specials
    , [("print", mkFunc 1 prnt)]
    ] where
        prnt :: PhageFunc
        prnt []  t = ret (putStrLn "") (PList [], t)
        prnt lst t = ret (mapM print lst) (last lst, t)

        ret :: IO a -> b -> ExceptT PhageErr IO b
        ret a b = ExceptT $ fmap (const (Right b)) $ a

phagelude :: Map String PhageVal
phagelude = newTab allVals mempty
