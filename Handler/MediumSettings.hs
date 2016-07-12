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

module Handler.MediumSettings where

import Import
import Handler.Commons
import System.Directory
import System.FilePath
import qualified Data.Text as T
import Data.List (tail)

getMediumSettingsR :: MediumId -> Handler Html
getMediumSettingsR mediumId = do
  checkRes <- mediumCheck mediumId
  case checkRes of
    Right medium -> do
      (mediumSettingsWidget, enctype) <- generateFormPost $
        renderBootstrap3 BootstrapBasicForm $
        mediumSettingsForm medium
      formLayout $ do
        setTitle "Eidolon :: Medium Settings"
        $(widgetFile "mediumSettings")
    Left (errorMsg, route) -> do
      setMessage errorMsg
      redirect route

postMediumSettingsR :: MediumId -> Handler Html
postMediumSettingsR mediumId = do
  checkRes <- mediumCheck mediumId
  case checkRes of
    Right medium -> do
      ((result, _), _) <- runFormPost $
        renderBootstrap3 BootstrapBasicForm $
        mediumSettingsForm medium
      case result of
        FormSuccess temp -> do
          _ <- runDB $ update mediumId
            [ MediumTitle =. mediumTitle temp
            , MediumDescription =. mediumDescription temp
            , MediumTags =. mediumTags temp
            ]
          updateIndexES (ESMedium mediumId temp)
          setMessage "Medium settings changed succesfully"
          redirect $ MediumR mediumId
        _ -> do
          setMessage "There was an error changing the settings"
          redirect $ MediumSettingsR mediumId
    Left (errorMsg, route) -> do
      setMessage errorMsg
      redirect route

mediumSettingsForm :: Medium -> AForm Handler Medium
mediumSettingsForm medium = Medium
  <$> areq textField (bfs ("Title" :: T.Text)) (Just $ mediumTitle medium)
  <*> pure (mediumPath medium)
  <*> pure (mediumThumb medium)
  <*> pure (mediumMime medium)
  <*> pure (mediumTime medium)
  <*> pure (mediumOwner medium)
  <*> aopt textareaField (bfs ("Description" :: T.Text)) (Just $ mediumDescription medium)
  <*> areq tagField (bfs ("tags" :: T.Text)) (Just $ mediumTags medium)
  <*> pure (mediumWidth medium)
  <*> pure (mediumThumbWidth medium)
  <*> pure (mediumAlbum medium)
  <*> pure (mediumPreview medium)
  <*> pure (mediumPreviewWidth medium)
  <*  bootstrapSubmit ("Change settings" :: BootstrapSubmit T.Text)

getMediumDeleteR :: MediumId -> Handler Html
getMediumDeleteR mediumId = do
  checkRes <- mediumCheck mediumId
  case checkRes of
    Right medium ->
      formLayout $ do
        setTitle "Eidolon :: Delete Medium"
        $(widgetFile "mediumDelete")
    Left (errorMsg, route) -> do
      setMessage errorMsg
      redirect route

postMediumDeleteR :: MediumId -> Handler Html
postMediumDeleteR mediumId = do
  checkRes <- mediumCheck mediumId
  case checkRes of
    Right medium -> do
      confirm <- lookupPostParam "confirm"
      case confirm of
        Just "confirm" -> do
          -- delete comments
          commEnts <- runDB $ selectList [CommentOrigin ==. mediumId] []
          _ <- mapM (runDB . delete . entityKey) commEnts
          -- delete references first
          let albumId = mediumAlbum medium
          album <- runDB $ getJust albumId
          let mediaList = albumContent album
          let newMediaList = removeItem mediumId mediaList
          -- update reference List
          runDB $ update albumId [AlbumContent =. newMediaList]
          liftIO $ removeFile (normalise $ tail $ mediumPath medium)
          liftIO $ removeFile (normalise $ tail $ mediumThumb medium)
          liftIO $ removeFile (normalise $ tail $ mediumPreview medium)
          runDB $ delete mediumId
          -- delete form elasticsearch
          deleteIndexES (ESMedium mediumId medium)
          setMessage "Medium succesfully deleted"
          redirect HomeR
        _ -> do
          setMessage "You must confirm the deletion"
          redirect $ MediumSettingsR mediumId
    Left (errorMsg, route) -> do
      setMessage errorMsg
      redirect route
