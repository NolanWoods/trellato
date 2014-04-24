###
To Do:
	* get it serving
	* get it rebuilding
	* get it reloading
	- get it injecting
	- bower-inject
	- get it coffeeing
	- less

	- inlining - https://github.com/hemanth/gulp-replace, https://github.com/gabrielflorit/gulp-smoosher
	- CDN'ing https://www.npmjs.org/package/gulp-google-cdn/ https://www.npmjs.org/package/gulp-cdnizer/
	- uglify / angular-dependency-injecty-safe-ify

	- use gulp-load-plugins
	- chrome map between script and coffee?
	- have watcher not crash on syntax error
###

gulp = require 'gulp'
bowerFiles = require 'gulp-bower-files'
concat = require 'gulp-concat'
clean = require 'gulp-clean'
coffee = require 'gulp-coffee'
connect = require 'connect'
embedReloader = require 'gulp-embedlr'
#es = require 'event-stream'
http = require 'http'
inject = require 'gulp-inject'
less = require 'gulp-less'
liveReload = require 'gulp-livereload'
gulpReplace = require 'gulp-replace'

trellatoConfig = require './config'

serverPort = 31337
paths =
	dest: 'build'
	html: 'src/index.html'
	scripts: 'src/**/*.coffee'
	styles: 'src/**/*.less'


gulp.task 'clean', ->
	gulp.src paths.dest, {read: false}
		.pipe clean()

gulp.task 'config', (done) ->
	console.log trellatoConfig.trelloApiKey

gulp.task 'html', ->
	injectOpts = 
	gulp.src paths.html
		.pipe gulpReplace '%TRELLO_API_KEY%', trellatoConfig.trelloApiKey
		.pipe gulpReplace '%ORG_ID%', trellatoConfig.orgId
		.pipe inject (bowerFiles().pipe gulp.dest "#{ paths.dest }/lib"), {ignorePath: 'build'}
		.pipe embedReloader()
		.pipe gulp.dest paths.dest


gulp.task 'scripts', ->
	gulp.src paths.scripts
		.pipe coffee()
		.pipe concat 'script.js'
		.pipe gulp.dest paths.dest


gulp.task 'styles', ->
	gulp.src paths.styles
		.pipe less()
		.pipe concat 'styles.css'
		.pipe gulp.dest paths.dest


gulp.task 'server', ['html', 'scripts', 'styles'], (done) ->
	server = http.createServer (connect()
				.use connect.logger 'dev'
				.use connect.static 'build')
		.listen serverPort
		.on 'error', (error) ->
			console.log 'ERROR: unable to start server', error
			done(error)
		.on 'listening', ->
			console.log 'Server listening on', server.address().port
			done()


gulp.task 'watch', ['html', 'scripts', 'styles'], ->
	gulp.watch paths.styles, ['styles']
	gulp.watch paths.scripts, ['scripts']
	gulp.watch paths.html, ['html']

	lr = liveReload();
	gulp.watch "#{ paths.dest }/**"
		.on 'change', (file) -> lr.changed file.path


gulp.task 'default', ['server', 'watch']
