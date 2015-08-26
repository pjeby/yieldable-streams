gulp = require('gulp')
mocha = require 'gulp-mocha'
coffee = require 'gulp-coffee'
regenerator = require 'gulp-regenerator'

require 'coffee-script/register'
require('babel-core/polyfill')

package_name = JSON.parse(require('fs').readFileSync "package.json").name
main = "#{package_name}.litcoffee"

gulp.task 'build', ->
    gulp.src(main)
    .pipe coffee()
    #.on 'error', ->gutil.log
    .pipe gulp.dest('.')
    #.pipe filelog()

gulp.task 'test', ['build'], ->
    gulp.src 'spec.*coffee'
    .pipe coffee()
    .pipe regenerator(includeRuntime: false)  # the polyfill installs it
    .pipe gulp.dest('.')
    .pipe mocha
        reporter: "spec"
        useColors: yes
        fullStackTrace: yes
        #bail: yes
    .on "error", (err) ->
        console.log err.toString()
        console.log err.stack if err.stack?
        @emit 'end'

gulp.task 'default', ['test'], ->
    gulp.watch ['README.md', main, 'spec.*coffee'], ['test']
