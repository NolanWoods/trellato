###
To Do:

	- inlining - https://github.com/hemanth/gulp-replace, https://github.com/gabrielflorit/gulp-smoosher
	- CDN'ing https://www.npmjs.org/package/gulp-google-cdn/ https://www.npmjs.org/package/gulp-cdnizer/
	- uglify / angular-dependency-injecty-safe-ify

	- use gulp-load-plugins
	- chrome map between script and coffee?
	- have watcher not crash on syntax error
	- find a better way to inject the config
###

try
	trellatoConfig = require './config'
catch
	throw new Error "config.js not found. copy and edit from config.sample.js" 

gulp = require 'gulp'
connect = require 'connect'
http = require 'http'
plugins = (require 'gulp-load-plugins')()

serverPort = 31337
paths =
	dest: 'build'
	html: 'src/index.html'
	scripts: 'src/**/*.coffee'
	styles: 'src/**/*.less'


gulp.task 'clean', ->
	gulp.src paths.dest, {read: false}
		.pipe plugins.clean()

gulp.task 'config', (done) ->
	console.log trellatoConfig.trelloApiKey

gulp.task 'html', ->
	bowerFiles = plugins.bowerFiles().pipe gulp.dest "#{ paths.dest }/lib"
	gulp.src paths.html
		.pipe plugins.replace '%TRELLO_API_KEY%', trellatoConfig.trelloApiKey
		.pipe plugins.replace '%ORG_ID%', trellatoConfig.orgId
		.pipe plugins.inject bowerFiles, {ignorePath: 'build'}
		.pipe plugins.embedlr()
		.pipe gulp.dest paths.dest


gulp.task 'scripts', ->
	gulp.src paths.scripts
		.pipe plugins.coffee()
		.pipe plugins.concat 'script.js'
		.pipe gulp.dest paths.dest


gulp.task 'styles', ->
	gulp.src paths.styles
		.pipe plugins.less()
		.pipe plugins.concat 'styles.css'
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

	lr = plugins.livereload();
	gulp.watch "#{ paths.dest }/**"
		.on 'change', (file) -> lr.changed file.path


gulp.task 'default', ['server', 'watch']
