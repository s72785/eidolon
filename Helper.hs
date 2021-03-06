module Helper 
  ( getUserIdFromText
  , extractKey
--  , getUserNameById
  , fromHex
  , fromHex'
  , toHex
  , makeRandomToken
  , generateSalt
  , tagField
  , userField
  , sendMail
  , generateString
  , removeItem
  , acceptedTypes
  )
where

import Prelude
import Model
import Control.Applicative
import Control.Monad.Trans.Class
import Data.Maybe
import Data.Either
import Data.List
import qualified Data.ByteString as B
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Char8 as BC
import qualified Data.Text as T
import Database.Persist
import Database.Persist.Types
import System.FilePath
import System.Random
import Yesod.Persist.Core
import Yesod.Core.Types
import Yesod
import Numeric (readHex, showHex)
import Network.Mail.Mime
import Text.Blaze.Html.Renderer.Utf8

getUserIdFromText :: T.Text -> UserId
getUserIdFromText tempUserId =
  Key $ PersistInt64 $ fromIntegral $ read $ T.unpack tempUserId

extractKey :: KeyBackend backend entity -> T.Text
extractKey = extractKey' . unKey
  where
    extractKey' (PersistInt64 k) = T.pack $ show k
    extractKey' _ = ""

--getUserNameById :: UserId -> Text
--getUserNameById userId =
--  let
--    user = runDB $ getJust $ userId
--  in
--    userName user

fromHex :: String -> BL.ByteString
fromHex = BL.pack . hexToWords
  where hexToWords (c:c':text) =
          let hex = [c, c']
              (word, _):_ = readHex hex
          in word : hexToWords text
        hexToWords _ = []

-- strict variant

fromHex' :: String -> B.ByteString
fromHex' = B.concat . BL.toChunks . fromHex

toHex :: B.ByteString -> T.Text
toHex = T.pack . concatMap mapByte . B.unpack
  where mapByte = pad 2 '0' . flip showHex ""
        pad len padding s
          | length s < len = pad len padding $ padding:s
          | otherwise = s

makeRandomToken :: IO T.Text
makeRandomToken = (T.pack . take 16 . randoms) `fmap` newStdGen

generateSalt :: IO B.ByteString
generateSalt = (B.pack . take 8 . randoms) <$> getStdGen

tagField :: Monad m => Field m [T.Text]
tagField = Field
  { fieldParse = \rawVals _ -> do
      case rawVals of
        [x] -> case null [x] of
          False -> return $ Right $ Just $ removeItem "" $ T.splitOn " " x
          True -> return $ Right $ Nothing
        _   -> return $ Left  $ error "unexpected tag list"
  , fieldView = \idAttr nameAttr val eResult isReq ->
      [whamlet|<input id=#{idAttr} type="text" name=#{nameAttr} value=#{either id (T.intercalate " ") eResult}>|]
  , fieldEnctype = UrlEncoded
  }

userField :: Monad m => [(T.Text, UserId)] -> Field m [UserId]
userField users = Field
  { fieldParse = \rawVals _ -> do
      case rawVals of
        [x] -> case x == "" of
          False ->
            -- clean = removeItem "" $ T.splitOn " " x
            let ids = map (\u -> lookup u users) (removeItem "" $ T.splitOn " " x)
            in case Nothing `elem` ids of
                False -> return $ Right $ Just $ nub $ map fromJust ids
                True -> return $ Left $ error "Invalid username list"
          True -> return $ Right $ Just $ []
        _ -> return $ Left $ error "unexpected username list"
  , fieldView = \idAttr nameAttr val eResult isReq ->
      [whamlet|<input id=#{idAttr} type="text" name=#{nameAttr} value=#{either id (getUsersFromResult users) eResult}>|]
  , fieldEnctype = UrlEncoded
  }

getUsersFromResult users res = T.intercalate " " $ map (\x -> fromMaybe "" $ reverseLookup x users) res

sendMail :: MonadIO m => T.Text -> T.Text -> Html -> m ()
sendMail toEmail subject body =
  liftIO $ renderSendMail
    Mail
      { mailFrom = Address Nothing "noreply" -- TODO: set sender Address
      , mailTo = [Address Nothing toEmail]
      , mailCc = []
      , mailBcc = []
      , mailHeaders = [("Subject", subject)]
      , mailParts = [[Part
        { partType = "text/html; charset=utf-8"
        , partEncoding = None
        , partFilename = Nothing
        , partHeaders = []
        , partContent = renderHtml body
        }]]
      }

generateString :: IO T.Text
generateString = (toHex . B.pack . take 16 . randoms) <$> newStdGen

removeItem :: Eq a => a -> [a] -> [a]
removeItem _ [] = []
removeItem x (y:ys)
  | x == y    = removeItem x ys
  | otherwise = y : removeItem x ys

reverseLookup :: Eq b => b -> [(a, b)] -> Maybe a
reverseLookup s ((x, y):zs)
  | s == y    = Just x
  | s /= y    = reverseLookup s zs
  | otherwise = Nothing

acceptedTypes :: [T.Text]
acceptedTypes = ["image/jpeg", "image/jpg", "image/png", "image/x-ms-bmp", "image/x-bmp", "image/bmp", "image/tiff", "image/tiff-fx"]
