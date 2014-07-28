gulp = require 'gulp'
plugins = (require 'gulp-load-plugins')() 

browserify = require 'browserify'
watchify = require 'watchify'
sourcify = require 'vinyl-source-stream'

Promise = require 'promise'
debug = require 'debug'
path = require 'path'
rimraf = require 'rimraf'
should = require 'should'

## Config

try
  trellatoConfig = require './config'
catch
  throw new Error 'config.js not found. copy and edit from config.sample.js'

src = 
  html: './src/index.html'
  scripts: './src/app.coffee'
  styles: './src/styles.less'

paths =
  build: path.resolve './build/'

livereloadPort = 35729


gulp.task 'clean', (done) -> rimraf paths.build, done

gulp.task 'build-vendor', ['clean'], -> buildVendor()

gulp.task 'build-scripts', ['clean'], -> (scriptBuilder false).build()

gulp.task 'build-styles', ['clean'], -> buildStyles()

gulp.task 'build', ['build-vendor', 'build-scripts', 'build-styles'], 
  -> buildIndex()

gulp.task 'lint', ['lint-coffee']

gulp.task 'lint-coffee', ->
  gulp.src ['./*.coffee', './src/**/*.coffee'], read: true
    .pipe plugins.coffeelint '.coffeelintrc'
    .pipe plugins.coffeelint.reporter()


gulp.task 'watch', (done) ->
  scripts = scriptBuilder true    
  server = null
  livereload = null

  # close existing connections so gulp will exit
  errHandler = (err) ->
    scripts.close()
    server?.close()
    livereload?.close()
    done err

  reloadIndex = -> notify livereload, 'index.html'
  buildAndReloadIndex = -> (buildIndex true).then reloadIndex

  # build everything and start the servers
  Promise.all [ buildVendor(), buildStyles(), scripts.build() ]
    .then buildIndex true
    .then (-> startServer().then (srv) -> server = srv)
    .then (-> startLivereload().then (lr) -> livereload = lr)
    .then reloadIndex
    .then null, errHandler


  # watch files and update
  gulp.watch src.html, buildAndReloadIndex
  gulp.watch src.styles, -> 
    buildStyles().then -> 
      notify livereload, 'styles.css'
  scripts.on 'update', -> scripts.build().then buildAndReloadIndex

  return


## Functions

buildVendor = -> new Promise (resolve) ->
  log = debug 'gulp:buildVendor'
  log 'building vendor.js'
  plugins.bowerFiles()
    .pipe plugins.concat 'vendor.js'
    .pipe gulp.dest paths.build
    .on 'end', resolve

buildStyles = -> new Promise (resolve) ->
  gulp.src src.styles
      .pipe plugins.less()
      .pipe plugins.concat 'styles.css'
      .pipe gulp.dest paths.build
      .on 'end', resolve

scriptBuilder = (watch) ->
  log = debug 'gulp:scriptBuilder'
  bundler = (if watch then watchify else browserify) src.scripts
  bundler.transform 'coffeeify'
    .on 'log', (msg) -> log '... ' + msg
  bundler.build = ->
    log 'building app.js'
    new Promise (resolve) ->
      bundler.bundle { debug: true, extensions: ['.coffee'] }
        .pipe sourcify 'app.js'
        .pipe gulp.dest paths.build
        .on 'end', resolve
  bundler

buildIndex = (livereload) -> 
  log = debug 'gulp:buildIndex'
  log 'building index.html'    
  
  inject = (src, tag) ->
    # gulp-inject is super finicky about the tags; make sure the spacing
    # in the comment tags exactly matches what is produced from the .jade
    srcFiles = gulp.src src, {cwd: paths.build, read: false}
    plugins.inject srcFiles, 
      starttag: "<!-- inject:#{tag}:{{ext}}-->"
      endtag: '<!-- endinject-->'
  new Promise (resolve) ->
    p = gulp.src src.html
      .pipe inject './vendor.js', 'vendor'
      .pipe inject './app.js', 'app'    
      .pipe plugins.replace '%TRELLO_API_KEY%', trellatoConfig.trelloApiKey
      .pipe plugins.replace '%ORG_ID%', trellatoConfig.orgId
    p = p.pipe plugins.embedlr() if livereload
    p = p.pipe gulp.dest paths.build
      .on 'end', resolve

startServer = (livereload) -> new Promise (resolve) ->
  express = require 'express'
  app = express()
    .set 'port', process.env.PORT or 3000
    .use express.static paths.build  
  if livereload
    app.use (require 'connect-livereload')
  server = app.listen (app.get 'port'), ->
    plugins.util.log "server listening on port #{ server.address().port}"
    resolve server

startLivereload = ->
  new Promise (resolve, reject) ->
    lrServer = (require 'tiny-lr')()
    lrServer.listen livereloadPort, (err) ->
      if err? then reject err 
      else
        plugins.util.log "tiny-lr listening on #{ livereloadPort }" 
        resolve lrServer

notify = (livereload, file) ->
  (debug 'gulp:notify') file
  livereload.changed {body: {files: [file]}}