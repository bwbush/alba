{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE CApiFFI #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE ScopedTypeVariables #-}

module ALBA where

import Control.Exception (bracket)
import Data.Bits (setBit, shiftR, (.&.))
import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Base16 as Hex
import Data.ByteString.Internal (toForeignPtr0)
import Data.Functor (void)
import qualified Data.List as List
import Data.Serialize (encode)
import Foreign (Ptr, Word8, countTrailingZeros, free, mallocBytes, peekArray, withForeignPtr)
import System.IO.Unsafe (unsafePerformIO)

foreign import capi unsafe "blake2b.h blake2b256_hash" blake2b256_hash :: Ptr Word8 -> Int -> Ptr Word8 -> IO Int

{- | ALBA parameters.

The goal of ALBA is that given a set of elements $S_p$ known to the prover,
such that $|S_p| \geq n_p$, the prover can convince the verifier that $|S_p| \geq n_f$
with $n_f < n_p$.
-}
data Params = Params
    { λ_sec :: Integer
    -- ^ Security parameter
    -- Controls the probability that `extract` returns a set of size less than `n_f`.
    -- 128 seems like a good value
    , λ_rel :: Integer
    -- ^ Verification parameter.
    -- Controls the probability that `verify` returns `True` when the proof is invalid.
    -- 128 seems like a good value
    , n_p :: Integer
    -- ^ Estimated size of "honest" parties set.
    , n_f :: Integer
    -- ^ Estimated size of "adversarial" parties set.
    }
    deriving (Show)

-- | Weight function for type `a`.
type W a = a -> Int

newtype Proof = Proof (Integer, [Bytes])
    deriving (Show, Eq)

class Hashable a where
    hash :: a -> ByteString

instance Hashable Integer where
    hash = hash . encode

instance Hashable ByteString where
    hash bytes =
        unsafePerformIO $ bracket (mallocBytes 32) free $ \out ->
            let (foreignPtr, len) = toForeignPtr0 bytes
             in withForeignPtr foreignPtr $ \ptr -> do
                    void $ blake2b256_hash ptr len out
                    BS.pack <$> peekArray 32 out

instance (Hashable a) => Hashable [a] where
    hash = hash . BS.concat . map hash

instance (Hashable a, Hashable b) => Hashable (a, b) where
    hash (a, b) = hash $ hash a <> hash b

newtype Bytes = Bytes ByteString
    deriving newtype (Hashable, Eq)

instance Show Bytes where
    show (Bytes bs) = show $ Hex.encode bs

-- | Output a proof `the set of elements known to the prover `s_p` has size greater than $n_f$.
prove :: Params -> [Bytes] -> Proof
prove params@Params{n_p} s_p =
    go (fromInteger u - 1) round0
  where
    round0 = [(t, [s_i]) | s_i <- s_p, t <- [1 .. d]]

    (u, d, q) = computeParams params

    h1 :: (Hashable a) => a -> Integer -> Bool
    h1 a n =
        let !h = hash a
            !m = h `oracle` n
         in m == 0

    go :: Int -> [(Integer, [Bytes])] -> Proof
    go 0 acc =
        let prob = ceiling $ 1 / q
            s_p'' = filter (flip h1 prob) acc
         in Proof $ head s_p''
    go n acc =
        let s_p' = filter (flip h1 n_p) acc
            s_p'' = [(t, s_i : s_j) | s_i <- s_p, (t, s_j) <- s_p']
         in go (n - 1) s_p''

computeParams :: Params -> (Integer, Integer, Double)
computeParams Params{λ_rel, λ_sec, n_p, n_f} =
    (u, d, q)
  where
    e = exp 1

    loge :: Double
    loge = logBase 2 e

    u =
        ceiling $
            (fromIntegral λ_sec + logBase 2 (fromIntegral λ_rel) + 1 + logBase 2 loge)
                / logBase 2 (fromIntegral n_p / fromIntegral n_f)

    d = (2 * u * λ_rel) `div` floor loge

    q :: Double
    q = 2 * fromIntegral λ_rel / (fromIntegral d * loge)

modBS :: ByteString -> Integer -> Integer
modBS bs q =
    let n = fromBytes bs q
     in n `mod` q

fromBytes :: ByteString -> Integer -> Integer
fromBytes bs q = BS.foldl' (\acc b -> (acc * 256 + fromIntegral b) `mod` q) 0 bs

fromBytesLE :: ByteString -> Integer
fromBytesLE = BS.foldr (\b acc -> acc * 256 + fromIntegral b) 0

toBytesLE :: Integer -> ByteString
toBytesLE n =
    BS.pack $ List.unfoldr go n
  where
    go 0 = Nothing
    go m = Just (fromIntegral m, m `shiftR` 8)

{- | Compute a "random" oracle from a `ByteString` that's lower than some integer `n`.

from ALBA paper, Annex C, p.50:

H0 and H1 need to output a uniformly distributed integer in [np]
(or 1 with probability $1/[np]$, which can be handled by outputting a
random integer and checking if it is 0). If $n_p$ is a power of 2, we
are done. Else, set a failure bound $ε_{fail}$, set $k =
⌈log2(n_p/ε_{fail})⌉$ , and set $d = ⌊2^k/n_p⌋$. Use H to produce a k-
bit string, interpret it as an integer i ∈ [0, 2^k − 1], fail if $i ≥
dn_p$ , and output $i \mod n_p$ otherwise. (Naturally, only the honest
prover and verifier will actually fail; dishonest parties can do
whatever they want.)
-}
oracle :: ByteString -> Integer -> Integer
oracle bytes n =
    if isPowerOf2 n
        then modPowerOf2 bytes n
        else modNonPowerOf2 bytes n

modNonPowerOf2 :: ByteString -> Integer -> Integer
modNonPowerOf2 bytes n =
    if i >= d * n
        then error "failed"
        else i `mod` n
  where
    k :: Integer = ceiling $ logBase 2 (fromIntegral n / εFail)
    d = 2 ^ k `div` n
    i = modPowerOf2 bytes (2 ^ k)

εFail :: Double
εFail = 1e-20

modPowerOf2 :: ByteString -> Integer -> Integer
modPowerOf2 bytes n =
    case dropWhile (== 0) $ BS.unpack $ toBytesLE n of
        (msb : rest) ->
            let
                nbytes = reverse $ List.foldl' (\k i -> setBit k i) 0 [0 .. countTrailingZeros msb - 1] : replicate (length rest) 0xff
                r = BS.pack $ zipWith (.&.) nbytes (BS.unpack bytes)
             in
                fromBytesLE r
        [] -> error "modPowerOf2: n is 0"

isPowerOf2 :: Integer -> Bool
isPowerOf2 n =
    let q :: Integer = truncate $ logBase 2 (fromIntegral n :: Double)
     in 2 ^ q == n

-- | Verify `Proof` that the set of elements known to the prover `s_p` has size greater than $n_f$.
verify :: Params -> Proof -> Bool
verify params@Params{n_p} (Proof (d, bs)) =
    let (u, _, q) = computeParams params

        fo item (0, n, acc) =
            let prf = item : acc
                toh = (n, prf)
                prob = ceiling $ 1 / q
                h = hash toh
                m =
                    if length prf < length bs
                        then oracle h n_p
                        else oracle h prob
             in (m, n, item : acc)
        fo _ (k, n, acc) = (k, n, acc)

        fst3 (a, _, _) = a
     in length bs == fromInteger u
            && ((== 0) . fst3) (foldr fo (0, d, []) bs)
