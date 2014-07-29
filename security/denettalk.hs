-- originally copied from http://lpaste.net/85305

import Data.List
import Data.Maybe

codeChr = "0123456789abcdefghijklmnopqrstuvwxyz!?#%-+"
multPl = 71

sDecodeText :: Int -> String -> String
sDecodeText tpass = go 1 0 . drop 10 where
   go i lastCVal (c1 : c2 : xs) = let
      i1 = maybe (error [c1]) id $ elemIndex c1 codeChr
      i2 = maybe (error [c2]) id $ elemIndex c2 codeChr
      charVal = (i2 * 42 + i1 - tpass + multPl * i - lastCVal * (13 + i * 7)) `mod` 1764
     in toEnum (charVal `mod` 256) : go (i+1) (i2+1) xs
   go _ _ "]" = []

t0 = "[NTCTC001|h5d9+n3j9tq?8h#mbzfx8xg+xoy8y2qq+k8io!pjjpx#th?l%mo+9?pi79b59n%+czm#m%?pz085+1c39em50nz37ogg50ep8e!tuiadfbfz9fnqmr0mpsp6ar1-h3jyh52+yxwz?%mxid1h52unsxdxipetorh%0awnu302w4xooly%-d-kvh%qowy4ri7oi4ds+w0s958grbp8y3!1ewag765?68g#t!51lpq4z-ffp#]"
t1 = "[NTCTC001|8p4erllzjhas1att8o7za195fi7-pp]"
t2 = "[NTCTC001|10s+x7#lu1mbswtduoh56%u82965g!tcxp]"

decode s = nub [t | i <- [0..1763], let t = sDecodeText i s, "<>" `isSuffixOf` t]

main = do
	putStrLn . decode t0
