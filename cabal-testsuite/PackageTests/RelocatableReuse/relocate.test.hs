import Test.Cabal.Prelude
import Test.Cabal.Monad (testWorkDir, testSourceCopyDir, testVerbosity)

import Control.Monad.Trans.Reader (withReaderT)
import Data.Foldable (for_)
import Distribution.Simple.Utils (copyDirectoryRecursive)
import System.Directory (copyFile, createDirectoryIfMissing)

-- The package is built under an @orig@ subdirectory and then relocated to a
-- @relocated@ subdirectory (both the sources and the dist tree move to a new
-- absolute path). Using subdirectories keeps the store\/home directories
-- outside the project root, matching real usage.
main = do
  skipIfWindows "does not support relocatable builds"
  cabalTest $ recordMode DoNotRecord $ do
    env <- getTestEnv
    let v = testVerbosity env
        root = testCurrentDir env
        origSrc = testSourceCopyDir env </> "orig"
        relocSrc = testSourceCopyDir env </> "relocated"
        origDist = testWorkDir env </> "work" </> "orig" </> "dist"
        relocDist = testWorkDir env </> "work" </> "relocated" </> "dist"
        copyPkg from to = liftIO $ do
          createDirectoryIfMissing True to
          copyFile (from </> "relocatable-reuse.cabal") (to </> "relocatable-reuse.cabal")
          copyFile (from </> "cabal.project") (to </> "cabal.project")
          copyDirectoryRecursive v (from </> "src") (to </> "src")
          copyDirectoryRecursive v (from </> "app") (to </> "app")
          copyDirectoryRecursive v (from </> "data") (to </> "data")

    -- The package is built under an @orig@ subdirectory and then relocated to a
    -- @relocated@ subdirectory (both the sources and the dist tree move to a new
    -- absolute path). Using subdirectories keeps the store\/home directories
    -- outside the project root, matching real usage.
    copyPkg root origSrc
    withReaderT (\e -> e{testRelativeCurrentDir = "orig"}) $
      cabal "build" ["--enable-relocatable"]

    copyPkg origSrc relocSrc
    liftIO $ copyDirectoryRecursive v origDist relocDist

    withReaderT (\e -> e{testRelativeCurrentDir = "relocated"}) $
      for_ [["--enable-relocatable"], mempty] $ \flag -> do
        r <- cabal' "build" flag
        assertOutputContains "Up to date" r
        assertOutputDoesNotContain "Compiling" r

