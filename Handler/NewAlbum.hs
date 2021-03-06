module Handler.NewAlbum where

import Import
import Data.Text
import System.Directory
import System.FilePath

getNewAlbumR :: Handler Html
getNewAlbumR = do
  msu <- lookupSession "userId"
  case msu of
    Just tempUserId -> do
      userId <- lift $ pure $ getUserIdFromText tempUserId
      (albumWidget, enctype) <- generateFormPost (albumForm userId)
      defaultLayout $ do
        setTitle "Eidolon :: Create new Album"
        $(widgetFile "newAlbum")
    Nothing -> do
      setMessage "You need to be logged in"
      redirect $ LoginR

postNewAlbumR :: Handler Html
postNewAlbumR = do
  msu <- lookupSession "userId"
  case msu of
    Just tempUserId -> do
      userId <- return $ getUserIdFromText tempUserId
      ((result, albumWidget), enctype) <- runFormPost (albumForm userId)
      case result of
        FormSuccess album -> do
          -- Put album in Database
          albumId <- runDB $ insert album
          -- add album reference in user
          user <- runDB $ getJust userId
          albumList <- return $ userAlbums user
          newAlbumList <- return $ albumId : albumList
          runDB $ update userId [UserAlbums =. newAlbumList]
          -- create folder
          liftIO $ createDirectory $ "static" </> "data" </> (unpack $ extractKey userId) </> (unpack $ extractKey albumId)
          -- outro
          setMessage $ "Album successfully created"
          redirect $ ProfileR userId
        _ -> do
          setMessage "There was an error creating the album"
          redirect $ NewAlbumR
    Nothing -> do
      setMessage "You must be logged in to create albums"
      redirect $ LoginR

albumForm :: UserId -> Form Album
albumForm userId = renderDivs $ Album
  <$> areq textField "Title" Nothing
  <*> pure userId
  <*> pure []
  <*> pure []
  <*> pure Nothing
