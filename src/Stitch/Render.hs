module Stitch.Render
  ( BlockPrinter
  , renderCSS
  , renderCSSWith
  , renderStitchTWith
  , basic
  , compressed ) where

import Control.Monad.Stitch
import Control.Monad.Trans.Stitch
import Stitch.Types

import Data.Monoid
import Data.Text (Text)
import qualified Data.Map as Map
import qualified Data.Text as Text

type BlockPrinter = (Block -> Text)
type InnerBlockPrinter = ([Selector] -> InnerBlock -> Text)

-- | Convert an abstract 'CSS' document to a real CSS document.
renderCSS :: CSS -> Text
renderCSS = renderCSSWith basic

-- | Convert an abstract 'CSS' document to a real CSS document using a specific printer. A simple printer called 'basic' is included, as well as a compressing printer called 'compressed'.
renderCSSWith :: BlockPrinter -> CSS -> Text
renderCSSWith f c = f $ snd $ runStitch c

renderStitchTWith :: Monad m => BlockPrinter -> StitchT m () -> m Text
renderStitchTWith f s = do
  (_, block) <- runStitchT s
  return $ f block

-- | Outputs a basic human-readable version of the CSS document. Line breaks are added between blocks, and properties are spaced nicely.
basic :: BlockPrinter
basic (Block is ps cs) =
  Text.intercalate "\n" $ map basicPropTL ps <> map ((<> ";") . basicImport) is <> collectChildren basicInner [] cs

basicInner :: InnerBlockPrinter
basicInner selectors (InnerBlock [] cs) =
  Text.intercalate " " $ collectChildren basicInner selectors cs
basicInner selectors (InnerBlock ps cs) =
  Text.intercalate "\n" $ Text.intercalate " "
    [ unSelector $ mconcat $ reverse selectors
    , "{\n "
    , Text.intercalate ";\n  " $ map basicProp ps
    , "\n}" ] : collectChildren basicInner selectors cs

basicImport :: Import -> Text
basicImport (Import i) = mconcat ["@import ", i]

basicProp :: Property -> Text
basicProp (Comment t) = mconcat ["/* ", t, " */"]
basicProp (Property k v) = mconcat [k, ": ", v]

basicPropTL :: Property -> Text
basicPropTL (Comment t) = mconcat ["/* ", t, "*/"]
basicPropTL _ = mempty

collectChildren :: InnerBlockPrinter -> [Selector] -> Children -> [Text]
collectChildren ibp selectors (Children cs) =
  map (\(k, v) -> ibp (k:selectors) v) $ Map.toList cs

-- | A minimal printer that aims for tiny output CSS. All spaces are removed.
compressed :: BlockPrinter
compressed (Block is _ cs) =
  mconcat $ map ((<> ";") . compressedImport) is <> collectChildren compressedInner [] cs

compressedInner :: InnerBlockPrinter
compressedInner selectors (InnerBlock [] cs) =
  Text.intercalate "" $ collectChildren compressedInner selectors cs
compressedInner selectors (InnerBlock ps cs) =
  Text.intercalate "" $ Text.intercalate ""
    [ unSelector $ mconcat $ reverse selectors
    , "{"
    , Text.intercalate ";" $ map compressedProp ps
    , "}" ] : collectChildren compressedInner selectors cs

compressedProp :: Property -> Text
compressedProp (Comment _) = mempty
compressedProp (Property k v) = mconcat [k, ":", v]

compressedImport :: Import -> Text
compressedImport = basicImport

unSelector :: Selector -> Text
unSelector (Selector t) = t
