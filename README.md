# yieldable-streams

Wouldn't it be great if you could create Node streams -- readable, writable, or duplex/transform/gulp plugins -- with just a single generator function?  Check this out:

<!-- mockdown-setup:  --printResults; languages.js = 'babel' -->

<!-- mockdown: waitForOutput = 'done' -->

```js
const
    {Readable, Writable, Duplex, Transform} = require('yieldable-streams'),

    fromIter = Readable.factory(
        function *(items) {
            for (var item of items) {
                yield this.write(item);
            }
        }
    ),

    times = Transform.factory(
        function *(multiplier) {
            var item;
            while ( (item = yield this.read()) !== null ) {
                yield this.write(item * multiplier);
            }
        }
    ),

    toConsole = Writable.factory(
        function *() {
            var item;
            while ( (item = yield this.read()) !== null ) {
                console.log(item);
            }
        }
    );

fromIter([3,5,9])
.pipe(times(2))
.pipe(toConsole())
.on('finish', () => console.log("done") );

console.log("start");
```

>     start
>     6
>     10
>     18
>     done

In the above code, the calls to `fromIter()`, `times()`, and `toConsole()` create *real*, honest-to-goodness Node streams: streams3 streams, in fact, straight from the [`readable-stream`](https://npmjs.com/package/readable-stream) package.  But on the inside, they're hooked up to generator functions, that can not only yield to `this.write()` etc., but also to promises, thunks, or other generator functions.

(You can use all the async yielding goodness of [`co`](https://npmjs.com/package/co), [`thunks`](https://npmjs.com/package/thunks), or any other coroutine wrapper library you like, in fact, as long as it supports yielding to thunks.)

And because these are true Node streams, that means you can write gulp plugins as easily as this (Javascript):

```js
module.exports = require('yieldable-streams').Transform.factory(

    function* (options) { /* plugin options */

        var file;

        while ( (file = yield this.read()) != null ) {  /* get a file */
            console.log(file.path);  /* do things with it */
            yield this.write(file);  /* pass it downstream */
        }

        /* do something with accumulated data here, or 
           maybe write() some new/added/merged files */
    }

);
```
Or this (CoffeeScript):

<!--mockdown: ++ignore-->

```coffee
module.exports = require('yieldable-streams').Transform.factory (options) ->

    while (file = yield @read())?   # get a file
        console.log file.path       # do stuff
        yield @write(file)          # pass it on

    # do other things
    
    return   # don't return anything, though
```

`yieldable-streams` does not actually use generators internally, and thus is compatible with node 0.10 and up.  You can use it with [`gnode`](https://npmjs.com/package/gnode), [`regenerator`](https://npmjs.com/package/regenerator), [`babel`](https://babeljs.io), [`harmonize`](https://npmjs.com/package/harmonize), [io.js](https://iojs.org/), or any other convenient way of implementing generators for your targeted versions of node.

(If you're writing a module or gulp plugin for node 0.10 or 0.12, though, we suggest precompiling with Babel or Regenerator.  That way, your users won't have to mess with node's command-line options or fuss with `require.extensions` hooks just to use your module.)


## Usage

Using `ys = require('yieldable-streams')` to get the module, you can access the following classes:

* `ys.Readable` - class to create readable streams
* `ys.Writable` - class to create writable streams
* `ys.Duplex` - class to create duplex streams
* `ys.Transform` - class to create transform streams

Each class works *just like* the corresponding `readable-stream` class, except for two extra methods.  The first extra method, on the instances, is the `spi()` method, which returns a "stream provider interface" object, for use with generator functions.

This "stream provider interface" object has (some or all of) the following methods:

* `read()` -- return a thunk for the next value written to the stream (`Writable`, `Duplex`, and `Transform` streams).  If stream input has ended, the thunk will yield a null or undefined value.  If a stream that is piped into the current stream fires an error event, that error will be received instead of the data, causing an exception at the point of `yield this.read()`

* `write(data[, enc])` -- `push(data[, enc])` onto the stream, returning a thunk that will fire when the stream is ready for more output (`Readable`, `Duplex`, and `Transform` streams only).

* `end(err)` -- end the stream, optionally with an error object to emit as an `"error"` event (all stream types).

Each stream class also has an added static method, `.factory(opts?, fn)`, which wraps the given function in such a way that when called, it will receive a stream provider interface as `this`, and will return the matching stream.  In this way, the function provides the stream's internal implementation, while the caller receives an ordinary stream object.

If `fn` is already wrapped by a coroutine library, such that it returns a thenable, promise or thunk, that return value will be hooked up to the `end()` method, so that unhandled exceptions will result in an `"error"` event, and a normal end to the coroutine will simply close the stream.  For example:

<!-- mockdown: ++ignore -->

```js
aFactory = Writable.factory(
  co.wrap(
    function *(...args) { /* 
    
      This generator will be run by `co`, but its `this` will still be
      the stream's `spi()`, so you can still `yield this.read()`.
        
      If the generator throws an uncaught exception, it will become an
      error event on the stream.  Otherwise, the stream will `finish`
      when the generator ends, unless you `this.end()` it first.
       
      Of course, for this to work, the library you use to do the
      wrapping must:

        * return a promise or a thunk (a 1-argument function taking a
          node-style callback) when called

        * allow you to yield to thunks and receive the data or errors
          they produce

      co.wrap() meets these criteria; other libraries' wrappers may
      do so as well.

    */ }
  )
)
```

If `fn`, however, returns a generator or is a generator function (i.e., it has *not* already been wrapped by a coroutine library, then `yieldable-streams` will wrap it using the [`thunks`](https://npmjs.com/package/thunks) library.  (Lazily-loaded, to minimize overhead if you're not using it.)

The optional `opts` object contains the `readable-stream` options that the factory will use to create the stream.  If unsupplied, it will default to `{objectMode: true}`, thereby creating an object stream suitable for use with, e.g. gulp.  See the [Node streams documentation](https://nodejs.org/api/stream.html) for more information on the possible options for each stream type.