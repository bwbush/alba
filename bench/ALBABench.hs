import ALBA (Bytes (..), Params (..), Proof, hash, prove)
import Control.Monad (forM)
import Criterion (Benchmark)
import Criterion.Main (bench, bgroup, defaultMain, nf, whnf)
import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import Data.Word (Word8)
import Test.QuickCheck (Gen, arbitrary, generate, vectorOf)

main :: IO ()
main = do
  benches <-
    forM
      [(s_p, 256) | s_p <- [1000, 5000, 10000, 50000, 100000]]
      genItems
  defaultMain
    [ bgroup "Hashing" [benchHash testBytes]
    , bgroup
        "Proof Generation"
        $ [ benchProof (b, s_p, n_p)
          | b <- benches
          , n_p <- [60, 66, 80]
          , let high = fromIntegral (length b)
          , let low = high * n_p `div` 100
          , let mid = (high + low) `div` 2
          , s_p <- [low, mid, high]
          ]
    ]

benchHash :: ByteString -> Benchmark
benchHash bytes =
  bench label $ nf hash bytes
 where
  label = "hashing len=" <> show (BS.length bytes)

benchProof :: ([ByteString], Int, Int) -> Benchmark
benchProof (bytes, s_p, n_p) =
  let coeff = fromIntegral $ length bytes
      params = Params 128 128 (coeff * fromIntegral n_p `div` 100) (coeff * (100 - fromIntegral n_p) `div` 100)
      label = show s_p <> "/" <> show coeff <> "/" <> show n_p <> "%"
   in bench label $
        whnf
          (uncurry prove)
          (params, Bytes <$> take s_p bytes)

genItems :: (Int, Int) -> IO [ByteString]
genItems (numItems, itemSize) =
  generate $ vectorOf numItems (BS.pack <$> vectorOf itemSize (arbitrary :: Gen Word8))

testBytes :: ByteString
testBytes =
  BS.pack
    -- Totally random, determined by fair dice rolls
    [ 0xa8
    , 0x53
    , 0x16
    , 0x1f
    , 0xef
    , 0x50
    , 0xc0
    , 0x6d
    , 0x7a
    , 0x21
    , 0xc1
    , 0xfa
    , 0x78
    , 0x33
    , 0x96
    , 0xf1
    , 0x7b
    , 0x2d
    , 0xa8
    , 0x4b
    , 0x5a
    , 0x7f
    , 0xe4
    , 0x49
    , 0x94
    , 0x5f
    , 0xe8
    , 0x9d
    , 0xd1
    , 0x41
    , 0xc6
    , 0x05
    , 0x03
    , 0xd9
    , 0x70
    , 0x9b
    , 0xa6
    , 0xe6
    , 0x5a
    , 0xce
    , 0xde
    , 0xe5
    , 0x78
    , 0x12
    , 0x87
    , 0x0f
    , 0x1d
    , 0x0d
    , 0x8c
    , 0x64
    , 0xbb
    , 0x82
    , 0xdc
    , 0xee
    , 0x31
    , 0x6c
    , 0xf0
    , 0xba
    , 0xc1
    , 0xfe
    , 0x44
    , 0xb7
    , 0x5e
    , 0x36
    , 0x86
    , 0x05
    , 0x4f
    , 0xad
    , 0x13
    , 0xc4
    , 0x03
    , 0x22
    , 0xd7
    , 0x07
    , 0x54
    , 0xf5
    , 0x0d
    , 0xdd
    , 0x73
    , 0x2a
    , 0x78
    , 0x75
    , 0x95
    , 0xb1
    , 0x3c
    , 0xa9
    , 0x7e
    , 0x75
    , 0xc5
    , 0x3f
    , 0x45
    , 0x35
    , 0x1a
    , 0xa0
    , 0x79
    , 0x44
    , 0xf3
    , 0xc4
    , 0x4c
    , 0x58
    , 0x2f
    , 0xfc
    , 0x5f
    , 0x8b
    , 0xad
    , 0x05
    , 0x2b
    , 0xbd
    , 0xcb
    , 0xfe
    , 0x2c
    , 0x83
    , 0x90
    , 0x7a
    , 0x8f
    , 0xbb
    , 0xd4
    , 0xde
    , 0xa6
    , 0x89
    , 0xc9
    , 0xb1
    , 0x70
    , 0xbe
    , 0xbc
    , 0x71
    , 0x6f
    , 0x63
    , 0xe5
    , 0xce
    , 0x21
    , 0xa6
    , 0xfd
    , 0xbf
    , 0xd6
    , 0x95
    , 0x76
    , 0xf9
    , 0x4c
    , 0x48
    , 0xa2
    , 0x15
    , 0xca
    , 0x2a
    , 0x2f
    , 0x82
    , 0xb4
    , 0xcb
    , 0x12
    , 0x24
    , 0x9a
    , 0x80
    , 0x66
    , 0xfc
    , 0x4e
    , 0xee
    , 0xc0
    , 0x87
    , 0x84
    , 0x0e
    , 0x37
    , 0xf2
    , 0x44
    , 0x56
    , 0x2c
    , 0xec
    , 0x16
    , 0xe6
    , 0x45
    , 0x3a
    , 0x2f
    , 0x5c
    , 0xa7
    , 0x71
    , 0xfb
    , 0xfc
    , 0x68
    , 0x5b
    , 0x30
    , 0x10
    , 0xac
    , 0x5f
    , 0x31
    , 0x06
    , 0xa9
    , 0xc4
    , 0x5a
    , 0x6e
    , 0xf2
    , 0x86
    , 0x68
    , 0xfb
    , 0x89
    , 0xf7
    , 0x32
    , 0x37
    , 0xe1
    , 0x71
    , 0xcd
    , 0x0c
    , 0xba
    , 0xfc
    , 0x03
    , 0xb9
    , 0x79
    , 0x25
    , 0x35
    , 0xcb
    , 0x3d
    , 0x77
    , 0x0a
    , 0x74
    , 0x02
    , 0x49
    , 0x5f
    , 0xdf
    , 0xfa
    , 0xac
    , 0xb9
    , 0x8c
    , 0xe0
    , 0xcb
    , 0x76
    , 0xfe
    , 0xc2
    , 0x7a
    , 0x6a
    , 0xc8
    , 0xa9
    , 0xd6
    , 0x1a
    , 0xe7
    , 0x5d
    , 0xba
    , 0xc6
    , 0xee
    , 0x93
    , 0x52
    , 0x60
    , 0xf2
    , 0xd7
    , 0x51
    , 0x22
    , 0xa8
    , 0x84
    , 0x29
    , 0x23
    , 0x5e
    , 0x1a
    , 0x55
    , 0xb0
    , 0xe8
    , 0xf9
    , 0x82
    , 0xb8
    , 0xf4
    ]
