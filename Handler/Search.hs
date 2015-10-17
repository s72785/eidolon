module Handler.Search where

import Import
import Handler.Commons
import Data.Time.Clock
import Data.Aeson
import Data.Maybe
import qualified Data.Text as T
import Database.Bloodhound
import Network.HTTP.Client (responseBody)
import System.FilePath.Posix

getSearchR :: Handler Html
getSearchR = do
  ((res, widget), _) <- runFormGet searchForm
  case res of
    FormSuccess query -> do
      (ru, ra, rm, rc) <- getResults query
      a <- return $ (decode (responseBody ru) :: Maybe (SearchResult SearchUser))
      b <- return $ (decode (responseBody ra) :: Maybe (SearchResult SearchAlbum))
      c <- return $ (decode (responseBody rm) :: Maybe (SearchResult SearchMedium))
      d <- return $ (decode (responseBody rc) :: Maybe (SearchResult SearchComment))
      hitListA <- case a of
        Just as -> return $ hits $ searchHits as
        Nothing -> return []
      hitListB <- case b of
        Just bs -> return $ hits $ searchHits bs
        Nothing -> return []
      hitListC <- case c of
        Just cs -> return $ hits $ searchHits cs
        Nothing -> return []
      hitListD <- case d of
        Just ds -> return $ hits $ searchHits ds
        Nothing -> return []
      userIdList <- return $ catMaybes $ map (\h -> do
        if
          hitIndex h == IndexName "user"
          then do
            DocId theId <- return $ hitDocId h
            Just $ (packKey theId :: UserId)
          else
            Nothing
        ) hitListA
      albumIdList <- return $ catMaybes $ map (\h -> do
        if
          hitIndex h == IndexName "album"
          then do
            DocId theId <- return $ hitDocId h
            Just $ (packKey theId :: AlbumId)
          else
            Nothing
        ) hitListB
      mediumIdList <- return $ catMaybes $ map (\h -> do
        if
          hitIndex h == IndexName "medium"
          then do
            DocId theId <- return $ hitDocId h
            Just $ (packKey theId :: MediumId)
          else
            Nothing
        ) hitListC
      commentIdList <- return $ catMaybes $ map (\h -> do
        if
          hitIndex h == IndexName "comment"
          then do
            DocId theId <- return $ hitDocId h
            Just $ (packKey theId :: CommentId)
          else
            Nothing
        ) hitListD
      userList <- return . catMaybes =<< mapM (\i -> runDB $ selectFirst [UserId ==. i] []) userIdList
      albumList <- return . catMaybes =<< mapM (\i -> runDB $ selectFirst [AlbumId ==. i] []) albumIdList
      mediumList <- return . catMaybes =<< mapM (\i -> runDB $ selectFirst [MediumId ==. i] []) mediumIdList
      commentList <- return . catMaybes =<< mapM (\i -> runDB $ selectFirst [CommentId ==. i] []) commentIdList
      let allEmpty = (null userList) && (null albumList) && (null mediumList) && (null commentList)
      defaultLayout $ do
        setTitle $ toHtml $ "Eidolon :: Search results for " ++ (T.unpack query)
        $(widgetFile "result")
    _ ->
      defaultLayout $ do
        setTitle "Eidolon :: Search"
        $(widgetFile "search")

searchForm :: Form T.Text
searchForm = renderDivs $ areq (searchField True) "Search" Nothing

getResults :: Text -> Handler (Reply, Reply, Reply, Reply)
getResults query = do
  let esQuery = QuerySimpleQueryStringQuery (SimpleQueryStringQuery (QueryString query) Nothing Nothing Nothing Nothing Nothing Nothing)
  su <- runBH' $ searchByIndex (IndexName "user") $ mkSearch (Just esQuery) Nothing
  sa <- runBH' $ searchByIndex (IndexName "album") $ mkSearch (Just esQuery) Nothing
  sm <- runBH' $ searchByIndex (IndexName "medium") $ mkSearch (Just esQuery) Nothing
  sc <- runBH' $ searchByIndex (IndexName "comment") $ mkSearch (Just esQuery) Nothing
  return (su, sa, sm, sc)

data SearchUser = SearchUser
  { suName :: T.Text
  , suSlug :: T.Text
  }

instance FromJSON SearchUser where
  parseJSON (Object o) = SearchUser
    <$> o .: "name"
    <*> o .: "slug"
  parseJSON _ = mempty

data SearchAlbum = SearchAlbum
  { saName :: T.Text }

instance FromJSON SearchAlbum where
  parseJSON (Object o) = SearchAlbum <$> o .: "name"
  parseJSON _ = mempty

data SearchMedium = SearchMedium
  { smName :: Text
  , smTime :: UTCTime
  , smDescription :: Textarea
  , smTags :: [T.Text]
  }

instance FromJSON SearchMedium where
  parseJSON (Object o) = SearchMedium
    <$> o .: "name"
    <*> o .: "time"
    <*> o .: "description"
    <*> o .: "tags"
  parseJSON _ = mempty

data SearchComment = SearchComment
  { scAuthor :: Text
  , scTime :: UTCTime
  , scContent :: Text
  }

instance FromJSON SearchComment where
  parseJSON (Object o) = SearchComment
    <$> o .: "author"
    <*> o .: "time"
    <*> o .: "content"
  parseJSON _ = mempty
