###
To Do:

    - CDN'ing https://www.npmjs.org/package/gulp-google-cdn/ 
        https://www.npmjs.org/package/gulp-cdnizer/
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
    tests: 'test/**/*.coffee'
    styles: 'src/**/*.less'


gulp.task 'lint', ->
    gulp.src [paths.scripts, 'gulpfile.coffee']
        .pipe plugins.coffeelint {
            indentation: {value: 4}
            no_trailing_whitespace: {level: 'ignore'}
            max_line_length: {value: 100}
        }
        .pipe plugins.coffeelint.reporter()

gulp.task 'lint-watch', ['lint'], -> gulp.watch paths.scripts, ['lint']


gulp.task 'lib', ->
    plugins.bowerFiles()
        .pipe plugins.flatten()
        .pipe plugins.concat 'lib.js'
        .pipe gulp.dest paths.dest


gulp.task 'karma', ['lib'], ->
    karma = require 'karma'
    karma.server.start {
        frameworks: ['mocha']
        preprocessors: {
            '**/*.coffee': ['coffee']
        }
        coffeePreprocessor: {
            options: {
                bare: true
                sourceMap: true
            }
        }
        files: [
            "#{ paths.dest }/lib.js"
            "./bower_components/angular-mocks/angular-mocks.js"
            { pattern: paths.scripts, watched: true }
            { pattern: paths.tests, watched: true }
        ]
    }

gulp.task 'clean', ->
    gulp.src paths.dest, {read: false}
        .pipe plugins.clean()

gulp.task 'config', (done) ->
    console.log trellatoConfig.trelloApiKey


errLogger = (taskName) ->
    errLabel = "[" + plugins.util.colors.bold.green(taskName) + "]"
    (err) ->
        #plugins.util.beep()
        plugins.util.log errLabel, err

gulp.task 'scripts', ->
    gulp.src paths.scripts
        .pipe plugins.concat 'app.coffee'
        .pipe gulp.dest paths.dest
        .pipe plugins.plumber { errorHandler: errLogger 'scripts' }
        .pipe plugins.coffee({bare: true, sourceMap: true})
#        .pipe plugins.ngmin()
        .pipe gulp.dest paths.dest


gulp.task 'styles', ->
    gulp.src paths.styles
        .pipe plugins.less()
        .pipe plugins.concat 'styles.css'
        .pipe gulp.dest paths.dest


gulp.task 'html', ['lib', 'scripts', 'styles'], ->
    gulp.src paths.html
        .pipe plugins.replace '%TRELLO_API_KEY%', trellatoConfig.trelloApiKey
        .pipe plugins.replace '%ORG_ID%', trellatoConfig.orgId
        .pipe plugins.embedlr()
#        .pipe plugins.inlineSource paths.dest
        .pipe gulp.dest paths.dest


gulp.task 'server', ['html'], (done) ->
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


gulp.task 'watch', ['html'], ->
    gulp.watch paths.styles, ['styles']
    gulp.watch paths.scripts, ['scripts']
    gulp.watch paths.html, ['html']


gulp.task 'livereload', ['watch'], ->
    lr = plugins.livereload()
    gulp.watch "#{ paths.dest }/**"
        .on 'change', (file) -> lr.changed file.path


gulp.task 'default', ['server', 'livereload']
