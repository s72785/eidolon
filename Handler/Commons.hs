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
