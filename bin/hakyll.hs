--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}

import           Data.Monoid (mappend)
import           Control.Applicative
import           Text.Pandoc.Options
import           System.FilePath
import           Hakyll

--------------------------------------------------------------------------------
main :: IO ()
main = hakyllWith config $ do
    match "static/**" $ do
        route   setRoot
        compile copyFileCompiler

    -- Tell hakyll to watch the less files
    match "assets/less/**.less" $ do
        compile getResourceBody

    -- Compile the main less file
    -- We tell hakyll it depends on all the less files,
    -- so it will recompile it when needed
    d <- makePatternDependency "assets/less/**.less"
    rulesExtraDependencies [d] $ create ["css/main.css"] $ do
        route idRoute
        compile $ loadBody "assets/less/main.less"
            >>= makeItem
            >>= withItemBody 
                (unixFilter "lessc" ["-","--include-path=assets/less","--yui-compress","-O2"])

    match "**.coffee" $ do
        route $ setRoot `composeRoutes` setExtension "js"
        compile $ getResourceString
            >>= withItemBody
                (unixFilter "coffee" ["--stdio", "--compile"])

    match "assets/js/**.js" $ do
        route $ setRoot `composeRoutes` setExtension "js"
        compile $ copyFileCompiler

    match ("pages/**") $ do
        route   $ setRoot `composeRoutes` cleanURL
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/page.html" baseCtx
            >>= loadAndApplyTemplate "templates/default.html" baseCtx
            >>= relativizeUrls

    match "posts/*" $ do
        route $ postRoute `composeRoutes` cleanURL
        compile $ pandocCompiler
            >>= saveSnapshot "content"
            >>= loadAndApplyTemplate "templates/post.html"    postCtx
            >>= loadAndApplyTemplate "templates/default.html" postCtx
            >>= relativizeUrls

    create ["archives.html"] $ do
        route cleanURL
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let archiveCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "title" "Archives"            `mappend`
                    constField "excerpt" "All posts by Zach Denton." `mappend`
                    baseCtx

            makeItem ""
                >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls


    create ["index.html"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let indexCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "title" "Noisehack" `mappend`
                    constField "excerpt" "Noisehack is a blog about audio programming." `mappend`
                    baseCtx

            makeItem ""
                >>= loadAndApplyTemplate "templates/index.html" indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    -- Render RSS feed
    create ["rss.xml"] $ do
        route idRoute
        compile $ do
            loadAllSnapshots "posts/*" "content"
                >>= fmap (take 10) . recentFirst
                >>= renderAtom feedConfiguration feedCtx

    match "templates/*" $ compile templateCompiler


--------------------------------------------------------------------------------
pandocWriterOptions :: WriterOptions
pandocWriterOptions = defaultHakyllWriterOptions { writerHTMLMathMethod = MathJax "" }

stripIndexLink :: (Item a -> Compiler String)
stripIndexLink = (fmap (maybe empty (dropFileName . toUrl)) . getRoute . itemIdentifier)

baseCtx :: Context String
baseCtx =
    field "url" stripIndexLink `mappend`
    listField "recentposts" postCtx (fmap (take 3) . recentFirst =<< fakePosts) `mappend`
    defaultContext

postCtx :: Context String
postCtx =
    dateField "date" "%B %e, %Y" `mappend`
    teaserField "teaser" "content" `mappend`
    baseCtx

feedCtx :: Context String
feedCtx =
    bodyField "description" `mappend`
    postCtx

fakePosts :: Compiler [Item String] 
fakePosts = do 
    identifiers <- getMatches "posts/*" 
    return [Item identifier "" | identifier <- identifiers] 

postRoute :: Routes
postRoute = customRoute $ drop 11 . stripTopDir

setRoot :: Routes
setRoot = customRoute stripTopDir

stripTopDir :: Identifier -> FilePath
stripTopDir = joinPath . tail . splitPath . toFilePath

cleanURL :: Routes
cleanURL = customRoute fileToDirectory

fileToDirectory :: Identifier -> FilePath
fileToDirectory = (flip combine) "index.html" . dropExtension . toFilePath

config :: Configuration
config = defaultConfiguration {
        deployCommand = "rsync -av _site/ _deploy/ && cd _deploy && git add -A && git commit -m 'update site' && git push origin gh-pages"
    }

feedConfiguration :: FeedConfiguration
feedConfiguration = FeedConfiguration {
    feedTitle = "Noisehack",
    feedDescription = "Audio programming articles, tutorials, and demos.",
    feedAuthorName = "Zach Denton",
    feedAuthorEmail = "z@chdenton.com",
    feedRoot = "http://noisehack.com"
}
