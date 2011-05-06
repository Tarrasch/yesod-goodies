-------------------------------------------------------------------------------
-- |
-- Module      :  Yesod.Goodies.Gravatar
-- Copyright   :  (c) Patrick Brisbin 2010 
-- License     :  as-is
--
-- Maintainer  :  pbrisbin@gmail.com
-- Stability   :  unstable
-- Portability :  unportable
--
-- Simple API into the gravatar system: <http://en.gravatar.com/>.
--
-------------------------------------------------------------------------------
module Yesod.Goodies.Gravatar
    ( 
    -- * Base request
      Email
    , gravatarImg

    -- * Options
    , GravatarOptions(..)
    , Size(..)
    , Default(..)
    , ForceDefault(..)
    , Rating(..)
    , defaultOptions

    ) where

import Data.Digest.Pure.MD5 (md5)
import Data.List            (intercalate)
import Data.Maybe           (catMaybes)
import Network.HTTP.Base    (urlEncode)

import qualified Data.ByteString.Lazy.Char8 as C8
import qualified Data.Text as T

-- | This is @'Text'@ because yesod is moving towards using that type in 
--   as many places as possible. It's what you should be storing in your 
--   database and what "Yesod.Form" already gives you out of an input.
type Email = T.Text

class GravatarParam a where
    toParam :: a -> Maybe (String, String)

newtype Size = Size Int

instance GravatarParam Size where
    toParam (Size i) = Just ("s", show i)

newtype ForceDefault = ForceDefault Bool

instance GravatarParam ForceDefault where
    toParam (ForceDefault b) = if b then Just ("f", "y") else Nothing

data Default = Custom String -- ^ supply your own url
             | NotFound      -- ^ do not load an image return a 404
             | MM            -- ^ mystery man
             | Identicon     -- ^ geometric pattern based on the hash
             | MonsterId     -- ^ a generated monster
             | Wavatar       -- ^ generated faces
             | Retro         -- ^ gernated, 8-bit arcade style pixelated face

instance GravatarParam Default where
    toParam (Custom s) = Just ("d", urlEncode s)
    toParam NotFound   = Just ("d", "404"      )
    toParam MM         = Just ("d", "mm"       )
    toParam Identicon  = Just ("d", "identicon")
    toParam MonsterId  = Just ("d", "monsterid")
    toParam Wavatar    = Just ("d", "wavatar"  )
    toParam Retro      = Just ("d", "retro"    )

data Rating = G | PG | R | X

instance GravatarParam Rating where
    toParam G  = Just ("r", "g" )
    toParam PG = Just ("r", "pg")
    toParam R  = Just ("r", "r" )
    toParam X  = Just ("r", "x" )

data GravatarOptions = GravatarOptions
    { gSize         :: Maybe Size
    , gDefault      :: Maybe Default
    , gForceDefault :: ForceDefault
    , gRating       :: Maybe Rating
    }

defaultOptions :: GravatarOptions
defaultOptions = GravatarOptions
    { gSize         = Nothing
    , gDefault      = Nothing
    , gForceDefault = ForceDefault False
    , gRating       = Nothing
    }

gravatarImg :: Email -> GravatarOptions -> String
gravatarImg e opts = "http://www.gravatar.com/avatar/" ++ hashEmail e `addParams` opts

-- | <http://en.gravatar.com/site/implement/hash/>
hashEmail :: T.Text -> String
hashEmail = md5sum . T.toLower . T.strip

    where
        md5sum :: T.Text -> String
        md5sum = show . md5 . C8.pack . T.unpack

addParams :: String -> GravatarOptions -> String
addParams url opts = helper url . map (\(k,v) -> k ++ "=" ++ v)
                   $ catMaybes [ fmap' toParam $ gSize         opts
                               , fmap' toParam $ gDefault      opts
                               ,       toParam $ gForceDefault opts
                               , fmap' toParam $ gRating       opts
                               ]
    where
        helper :: String -> [String] -> String
        helper u [] = u
        helper u l  = (++) u . (:) '?' $ intercalate "&" l

        fmap' :: (a -> Maybe b) -> Maybe a -> Maybe b
        fmap' _ Nothing  = Nothing
        fmap' f (Just x) = f x