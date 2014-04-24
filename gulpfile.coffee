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
###

gulp = require 'gulp'
concat = require 'gulp-concat'
clean = require 'gulp-clean'
connect = require 'connect'
embedReloader = require 'gulp-embedlr'
http = require 'http'
liveReload = require 'gulp-livereload'


gulp.env.serverPort = 31337
paths =
	scripts: 'src/**/*.js'
	html: 'src/index.html'
	dest: 'build'


gulp.task 'clean', ->
	gulp.src 'build', {read: false}
		.pipe clean()


gulp.task 'scripts', ->
	gulp.src paths.scripts
		.pipe concat 'script.js'
		.pipe gulp.dest paths.dest


gulp.task 'html', ->
	gulp.src paths.html
		.pipe embedReloader()
		.pipe gulp.dest paths.dest


gulp.task 'server', ['html', 'scripts'], (done) ->
	server = http.createServer (connect()
				.use connect.logger 'dev'
				.use connect.static 'build')
		.listen gulp.env.serverPort
		.on 'error', (error) ->
			console.log 'ERROR: unable to start server', error
			done(error)
		.on 'listening', ->
			console.log 'Server listening on', server.address().port
			done()


gulp.task 'watch', ['html', 'scripts'], ->
	gulp.watch paths.scripts, ['scripts']
	gulp.watch paths.html, ['html']

	lr = liveReload();
	gulp.watch "#{ paths.dest }/**"
		.on 'change', (file) -> lr.changed file.path


gulp.task 'default', ['server', 'watch']
