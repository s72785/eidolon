module Handler.Medium where

import Import
import Data.Time
import System.Locale

getMediumR :: MediumId -> Handler Html
getMediumR mediumId = do
  tempMedium <- runDB $ get mediumId
  case tempMedium of
    Just medium -> do
      ownerId <- return $ mediumOwner medium
      owner <- runDB $ getJust ownerId
      ownerName <- return $ userName owner
      msu <- lookupSession "userId"
      presence <- case msu of
        Just tempUserId -> do
          userId <- return $ getUserIdFromText tempUserId
          return (userId == ownerId)
        Nothing ->
          return False
      defaultLayout $ do
        $(widgetFile "medium")
    Nothing -> do
      setMessage "This image does not exist"
      redirect $ HomeR