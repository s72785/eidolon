--  eidolon -- A simple gallery in Haskell and Yesod
--  Copyright (C) 2015  Amedeo Molnár
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU Affero General Public License as published
--  by the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU Affero General Public License for more details.
--
--  You should have received a copy of the GNU Affero General Public License
--  along with this program.  If not, see <http://www.gnu.org/licenses/>.

module Handler.Commons where

import Import
import Data.String
import Database.Bloodhound
import Control.Monad (when)
import Network.HTTP.Client
import Network.HTTP.Types.Status as S
import qualified Data.ByteString.Char8 as C
import qualified Data.ByteString.Lazy as BL
import qualified Data.Text as T


loginIsAdmin :: IsString t => Handler (Either (t, Route App)  ())
loginIsAdmin = do
  msu <- lookupSession "userId"
  case msu of
    Just tempUserId -> do
      let userId = getUserIdFromText tempUserId
      user <- runDB $ getJust userId
      if
        userAdmin user
        then
          return $ Right ()
        else
          return $ Left ("You have no admin rights", HomeR)
    Nothing ->
      return $ Left ("You are not logged in", LoginR)

profileCheck :: IsString t => UserId -> Handler (Either (t, Route App) User)
profileCheck userId = do
  tempUser <- runDB $ get userId
  case tempUser of
    Just user -> do
      msu <- lookupSession "userId"
      case msu of
        Just tempLoginId -> do
          let loginId = getUserIdFromText tempLoginId
          if
            loginId == userId
            then
              return $ Right user
            else
              return $ Left ("You can only change your own profile settings", UserR $ userName user)
        Nothing ->
          return $ Left ("You nedd to be logged in to change settings", LoginR)
    Nothing ->
      return $ Left ("This user does not exist", HomeR)

mediumCheck :: IsString t => MediumId -> Handler (Either (t, Route App) Medium)
mediumCheck mediumId = do
  tempMedium <- runDB $ get mediumId
  case tempMedium of
    Just medium -> do
      let ownerId = mediumOwner medium
      msu <- lookupSession "userId"
      case msu of
        Just tempUserId -> do
          let userId = getUserIdFromText tempUserId
          album <- runDB $ getJust $ mediumAlbum medium
          let presence = userId == ownerId
          let albumOwnerPresence = userId == albumOwner album
          if
            presence || albumOwnerPresence
            then
              return $ Right medium
            else
              return $ Left ("You must own this medium to change its settings", MediumR mediumId)
        Nothing ->
          return $ Left ("You must be logged in to change settings", LoginR)
    Nothing ->
      return $ Left ("This medium does not exist", HomeR)

putIndexES :: ESInput -> Handler ()
putIndexES input = do
  master <- getYesod
  let shards = appShards $ appSettings master
  let replicas = appReplicas $ appSettings master
  let is = IndexSettings (ShardCount shards) (ReplicaCount replicas)
  resp <- case input of
    ESUser uId user -> do
      ex <- runBH' $ indexExists (IndexName "user")
      when (not ex) ((\ _ -> do
        runBH' $ createIndex is (IndexName "user")
        return ()
        ) ex)
      _ <- runBH' $ openIndex (IndexName "user")
      runBH' $ indexDocument (IndexName "user") (MappingName "user") defaultIndexDocumentSettings user (DocId $ extractKey uId)
    ESAlbum aId album -> do
      ex <- runBH' $ indexExists (IndexName "album")
      when (not ex) ((\ _ -> do
        runBH' $ createIndex is (IndexName "album")
        return ()
        ) ex)
      _ <- runBH' $ openIndex (IndexName "album")
      runBH' $ indexDocument (IndexName "album") (MappingName "album") defaultIndexDocumentSettings album (DocId $ extractKey aId)
    ESMedium mId medium -> do
      ex <- runBH' $ indexExists (IndexName "medium")
      when (not ex) ((\ _ -> do
        runBH' $ createIndex is (IndexName "medium")
        return ()
        ) ex)
      _ <- runBH' $ openIndex (IndexName "medium")
      runBH' $ indexDocument (IndexName "medium") (MappingName "medium") defaultIndexDocumentSettings medium (DocId $ extractKey mId)
    ESComment cId comment -> do
      ex <- runBH' $ indexExists (IndexName "comment")
      when (not ex) ((\ _ -> do
        runBH' $ createIndex is (IndexName "comment")
        return ()
        ) ex)
      _ <- runBH' $ openIndex (IndexName "comment")
      runBH' $ indexDocument (IndexName "comment") (MappingName "comment") defaultIndexDocumentSettings comment (DocId $ extractKey cId)
  case statusCode (responseStatus resp) of
    201 -> return ()
    -- 200 -> return ()
    _ -> error $ C.unpack $ BL.toStrict $ responseBody resp

deleteIndexES :: ESInput -> Handler ()
deleteIndexES input = do
  resp <- case input of
    ESUser uId user ->
      runBH' $ deleteDocument (IndexName "user") (MappingName "user") (DocId $ extractKey uId)
    ESAlbum aId album ->
      runBH' $ deleteDocument (IndexName "album") (MappingName "album") (DocId $ extractKey aId)
    ESMedium mId medium ->
      runBH' $ deleteDocument (IndexName "medium") (MappingName "medium") (DocId $ extractKey mId)
    ESComment cId comment ->
      runBH' $ deleteDocument (IndexName "comment") (MappingName "comment") (DocId $ extractKey cId)
  case statusCode (responseStatus resp) of
    201 -> return ()
    200 -> return ()
    _ -> error $ C.unpack $ BL.toStrict $ responseBody resp 

-- runBH' :: BH m a -> Handler resp
runBH' action = do
  master <- getYesod
  let s = appSearchHost $ appSettings master
  let server = Server s
  manager <- liftIO $ newManager defaultManagerSettings
  runBH (BHEnv server manager) action
