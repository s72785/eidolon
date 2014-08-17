module Handler.Upload where

import Import as I
import Data.Time
import Data.Text
import System.FilePath

data TempMedium = TempMedium
  { tempMediumTitle :: Text
  , tempMediumFile :: FileInfo
  , tempMediumTime :: UTCTime
  , tempMediumOwner :: UserId
  , tempMediumDesc :: Textarea
  , tempMediumTags :: [Text]
  , tempMediumAlbum :: AlbumId
  }

getUploadR :: Handler Html
getUploadR = do
  msu <- lookupSession "userId"
  case msu of
    Just tempUserId -> do
      userId <- lift $ pure $ getUserIdFromText tempUserId
      (uploadWidget, enctype) <- generateFormPost (uploadForm userId)
      defaultLayout $ do
        $(widgetFile "upload")
    Nothing -> do
      setMessage "You need to be logged in"
      redirect $ LoginR

postUploadR :: Handler Html
postUploadR = do
  msu <- lookupSession "userId"
  case msu of
    Just tempUserId -> do
      userId <- lift $ pure $ getUserIdFromText tempUserId
      ((result, uploadWidget), enctype) <- runFormPost (uploadForm userId)
      case result of
        FormSuccess temp -> do
          path <- writeOnDrive (tempMediumFile temp) userId (tempMediumAlbum temp)
          medium <- return $ Medium
            (tempMediumTitle temp)
            path
            (tempMediumTime temp)
            (tempMediumOwner temp)
            (tempMediumDesc temp)
            (tempMediumTags temp)
            (tempMediumAlbum temp)
          mId <- runDB $ I.insert medium
          setMessage "Image succesfully uploaded"
          redirect $ HomeR
        _ -> do
          setMessage "There was an error uploading the file"
          redirect $ UploadR
    Nothing -> do
      setMessage "You need to be logged in"
      redirect $ LoginR

writeOnDrive :: FileInfo -> UserId -> AlbumId -> Handler FilePath
writeOnDrive file userId albumId = do
  filename <- return $ fileName file
  path <- return $ "data"
    </> (unpack $ extractKey userId)
    </> (unpack $ extractKey albumId)
    </> (unpack filename)
  liftIO $ fileMove file path
  return path

uploadForm :: UserId -> Form TempMedium
uploadForm userId = renderDivs $ TempMedium
  <$> areq textField "Title" Nothing
  <*> areq fileField "Select file" Nothing
  <*> lift (liftIO getCurrentTime)
  <*> pure userId
  <*> areq textareaField "Description" Nothing
  <*> areq tagField "Enter tags" Nothing
  <*> areq (selectField albums) "Album" Nothing
  where
--    albums :: GHandler App App (OptionList AlbumId)
    albums = do
      entities <- runDB $ selectList [AlbumOwner ==. userId] [Desc AlbumTitle]
      optionsPairs $ I.map (\alb -> (albumTitle $ entityVal alb, entityKey alb)) entities

tagField :: Field Handler [Text]
tagField = Field
  { fieldParse = \rawVals _ -> do
      case rawVals of
        [x] -> return $ Right $ Just $ splitOn " " x
        _   -> return $ Left  $ error "unexpected tag list"
  , fieldView = \idAttr nameAttr _ eResult isReq ->
      [whamlet|<input id=#{idAttr} type="text" name=#{nameAttr}>|]
  , fieldEnctype = UrlEncoded
  }
