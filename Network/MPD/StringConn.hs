{-
    libmpd for Haskell, an MPD client library.
    Copyright (C) 2005-2007  Ben Sinclair <bsinclai@turing.une.edu.au>

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
-}

-- | Module    : Network.MPD.StringConn
-- Copyright   : (c) Ben Sinclair 2005-2007
-- License     : LGPL
-- Maintainer  : bsinclai@turing.une.edu.au
-- Stability   : alpha
-- Portability : Haskell 98
--
-- Connection over a network socket.

module Network.MPD.StringConn (testMPD) where

import Control.Monad (liftM)
import Network.MPD.Prim
import Data.IORef

-- | Run an action against a set of expected requests and responses,
-- and an expected result. The result is Nothing if everything matched
-- what was expected. If anything differed the result of the
-- computation is returned along with pairs of expected and received
-- requests.
testMPD :: (Eq a)
        => [(String, Response String)] -- ^ The expected requests and their
                                       -- ^ corresponding responses.
        -> Response a                  -- ^ The expected result.
        -> IO (Maybe String)           -- ^ An action that supplies passwords.
        -> MPD a                       -- ^ The MPD action to run.
        -> IO (Maybe (Response a, [(String,String)]))
testMPD pairs expt getpw m = do
    mismatchesRef <- newIORef ([] :: [(String, String)])
    expectsRef    <- newIORef $ concatMap (\(x,y) -> [Left x,Right y]) pairs
    let open'  = return ()
        close' = return ()
        put'   = put expectsRef mismatchesRef
        get'   = get expectsRef
    result <- runMPD m $ Conn open' close' put' get' getpw
    mismatches <- liftM reverse $ readIORef mismatchesRef
    return $ if null mismatches && result == expt
             then Nothing else Just (result, mismatches)

put :: IORef [Either String a]  -- An alternating list of expected
                                -- requests and responses to give.
    -> IORef [(String, String)] -- An initially empty list of
                                -- mismatches between expected and
                                -- actual requests.
    -> String
    -> IO (Response ())
put expsR mmsR x =
    let addMismatch x' = modifyIORef mmsR ((x',x):) >> return (Left NoMPD)
    in do
        ys <- readIORef expsR
        case ys of
            (Left y:_) | y == x ->
                           modifyIORef expsR (drop 1) >> return (Right ())
                       | otherwise -> addMismatch y
            _ -> addMismatch ""

get :: IORef [Either a (Response String)]
    -> IO (Response String)
get expsR = do
    xs <- readIORef expsR
    case xs of
        (Right x:_) -> modifyIORef expsR (drop 1) >> return x
        _           -> return $ Left NoMPD

