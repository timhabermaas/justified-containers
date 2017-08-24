{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -fdefer-type-errors #-}

module Data.Map.JustifiedSpec (main, spec) where

import Prelude hiding (lookup)

import Test.Hspec
import Test.QuickCheck
import Test.ShouldNotTypecheck

import Data.Map.Justified
import qualified Data.Map as M
import Data.Maybe

main :: IO ()
main = hspec spec

letters :: M.Map Char Int
letters = M.fromList (Prelude.zip ['a'..'z'] [1..])

newtype AlphaNum = AlphaNum Char deriving Show
instance Arbitrary AlphaNum where
  arbitrary = elements (map AlphaNum $ ['a'..'z'] ++ ['A'..'Z'] ++ ['0'..'9'])
  
spec :: Spec
spec = do

  describe "using Data.Map.Justified.Map" $ do

    it "wraps the underlying Data.Map.Map without modification" $ do
      withMap letters theMap == letters

    it "can create singleton maps" $ property $ do
      \(k :: Int, v :: Int) -> withSingleton k v (uncurry lookup) == v
      \(k :: Int, v :: Int) -> withSingleton k v (theMap . snd)   == M.fromList [(k,v)]
      
  describe "validated keys" $ do
    
    it "can be obtained iff a key is present" $ property $
      \(AlphaNum c) -> isJust (M.lookup c letters) == withMap letters (isJust . member c)

    it "will access the expected value" $ do
      map (\k -> fromJust $ M.lookup k letters) (M.keys letters)
      `shouldBe`
      withMap letters (\m -> map (`lookup` m) (keys m))
      
    it "can degrade to the original key" $ do
      M.keys letters `shouldBe` withMap letters (map theKey . keys)

    it "can still be used in an adjusted map" $ do
      withMap letters (\m -> let (k:k':_) = keys m in
                                 (lookup k (reinsert k 17 m),
                                  lookup k (reinsert k' 17 m),
                                  lookup k (adjust (+1) k m),
                                  lookup k (adjustWithKey
                                              (\k v -> v + fromEnum (theKey k)) k m)))
      `shouldBe` (17,1,2,98)
      
    it "can not escape `withMap`" $ shouldNotTypecheck $
      withMap letters (head keys)

    it "can not be used in unrelated maps" $ shouldNotTypecheck $
      withMap letters (\m ->
         let k = head (keys m) in withMap letters (lookup k))

    it  "can not be directly created" $ shouldNotTypecheck $
      let k = Key 'a' in withMap letters (lookup k)

  describe "when adding keys" $ do

    it "can translate old keys to new map" $ property $
      \(AlphaNum c, AlphaNum c') -> withMap letters $
        \m -> inserting c' 100 m $
              \(_, upgrade, m') ->
              let k  = member c m
                  k' = member c m'
              in c /= c' ==> fmap upgrade k == k'
  
    it "does not let a new key be used in the old map without translation" $
      shouldNotTypecheck $
        withMap letters $ \m -> inserting 'X' 100 m $
          \(_, _, m') -> map (`lookup` m) (keys m')
    
  describe "when removing keys" $ do

    it "can translate new keys to old map" $ property $
      \(AlphaNum c, AlphaNum c') -> withMap letters $
         \m -> deleting c' m $
               \(downgrade, m') ->
               let k  = member c m
                   k' = member c m'
               in c /= c' ==> k == fmap downgrade k'

    it "does not let an old key be used in the new map without translation" $
      shouldNotTypecheck $
        withMap letters $ \m -> deleting 'X' m $
          \(_, _, m') -> map (`lookup` m') (keys m)
    