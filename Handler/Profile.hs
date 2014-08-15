module Handler.Profile where

import Import
import Data.Maybe

getProfileR :: UserId -> Handler Html
getProfileR user = do
  owner <- runDB $ get user
  ownerName <- lift $ pure $ userName $ fromJust owner
  userAlbums <- runDB $ selectList [AlbumOwner ==. user] [Desc AlbumTitle]
  recentMedia <- (runDB $ selectList [MediumOwner ==. user] [Desc MediumTime])
  msu <- lookupSession "userId"
  case msu of
    Just tempUserId -> do
      userId <- lift $ pure $ getUserIdFromText tempUserId
      presence <- lift $ pure $ (Key userId) == user
      defaultLayout $ do
        $(widgetFile "profile")
