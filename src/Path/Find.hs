{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveDataTypeable #-}

-- | Finding files.

module Path.Find
  (findFileUp
  ,findDirUp
  ,findFiles)
  where

import Control.Monad
import Control.Monad.Catch
import Control.Monad.IO.Class
import Data.List
import Path
import Path.IO

-- | Find the location of a file matching the given predicate.
findFileUp :: (MonadIO m,MonadThrow m)
           => Path Abs Dir                -- ^ Start here.
           -> (Path Abs File -> Bool)     -- ^ Predicate to match the file.
           -> Maybe (Path Abs Dir)        -- ^ Do not ascend above this directory.
           -> m (Maybe (Path Abs File))  -- ^ Absolute file path.
findFileUp s p d = findPathUp snd s p d

-- | Find the location of a directory matching the given predicate.
findDirUp :: (MonadIO m,MonadThrow m)
          => Path Abs Dir                -- ^ Start here.
          -> (Path Abs Dir -> Bool)      -- ^ Predicate to match the directory.
          -> Maybe (Path Abs Dir)        -- ^ Do not ascend above this directory.
          -> m (Maybe (Path Abs Dir))   -- ^ Absolute directory path.
findDirUp s p d = findPathUp fst s p d

-- | Find the location of a path matching the given predicate.
findPathUp :: (MonadIO m,MonadThrow m)
           => (([Path Abs Dir],[Path Abs File]) -> [Path Abs t])
              -- ^ Choose path type from pair.
           -> Path Abs Dir                     -- ^ Start here.
           -> (Path Abs t -> Bool)             -- ^ Predicate to match the path.
           -> Maybe (Path Abs Dir)             -- ^ Do not ascend above this directory.
           -> m (Maybe (Path Abs t))           -- ^ Absolute path.
findPathUp pathType dir p upperBound =
  do entries <- listDirectory dir
     case find p (pathType entries) of
       Just path -> return (Just path)
       Nothing ->
         if Just dir == upperBound
            then return Nothing
            else if parent dir == dir
                    then return Nothing
                    else findPathUp pathType
                                    (parent dir)
                                    p
                                    upperBound

-- | Find files matching predicate below a root directory.
findFiles :: Path Abs Dir            -- ^ Root directory to begin with.
          -> (Path Abs File -> Bool) -- ^ Predicate to match files.
          -> (Path Abs Dir -> Bool)  -- ^ Predicate for which directories to traverse.
          -> IO [Path Abs File]      -- ^ List of matching files.
findFiles dir p traverse =
  do (dirs,files) <- listDirectory dir
     subResults <-
       forM dirs
            (\entry ->
               if traverse entry
                  then findFiles entry p traverse
                  else return [])
     return (concat (filter p files : subResults))
