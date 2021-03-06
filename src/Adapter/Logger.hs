{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE IncoherentInstances #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module Adapter.Logger where

import Control.Exception
import qualified Domain.Messages as D
import Katip
import RIO

class Show a => Loggable a where
  type F a
  log' :: a -> F (IO ())
  show' :: a -> Text

instance Show a => Loggable a where
  type F a = KatipContextT IO ()
  log' mess = $(logTM) ErrorS (showLS mess)
  show' = tshow

instance Show a => Loggable (D.Message a) where
  type F (D.Message a) = KatipContextT IO ()
  log' (D.ErrorMsg mess) = $(logTM) ErrorS (showLS $ show mess)
  log' (D.WarningMsg mess) = $(logTM) WarningS (showLS $ show mess)
  log' (D.InfoMsg mess) = $(logTM) InfoS (showLS $ show mess)
  log' (D.DebugMsg mess) = $(logTM) DebugS (showLS $ show mess)
  show' = tshow

log :: (MonadIO m, Loggable a) => [a] -> m ()
log elemsToLog = do
  handleScribe <- liftIO $ mkHandleScribe ColorIfTerminal stdout (permitItem DebugS) V2
  let mkLogEnv =
        registerScribe "stdout" handleScribe defaultScribeSettings
          =<< initLogEnv "MyApp" "production"
  liftIO $
    Control.Exception.bracket mkLogEnv closeScribes $ \le ->
      runKatipContextT le () mempty $ mapM_ log' elemsToLog
