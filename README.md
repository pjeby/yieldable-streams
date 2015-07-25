# yieldable-streams

Wouldn't it be great if you could create Node streams -- readable, writable, or duplex/transform/gulp plugins -- with just a single generator function?  Check this out:

<!-- mockdown: expect = 'done' -->

```es6
const
    {Readable, Writable, Duplex} = require('yieldable-streams'),

    fromIter = Readable.factory(
        function *(items) {
            for (var item of items) {
                yield this.write(item);
            }
        }
    ),

    times = Duplex.factory(
        function *(multiplier) {
            var item;
            while ((item = yield this.read()) != null) {
                yield this.write(item * multiplier);
            }
        }
    ),

    toConsole = Writable.factory(
        function *() {
            var item;
            while ((item = yield this.read()) != null) {
                console.log(item);
            }
        }
    );

fromIter([3,5,9])
.pipe(times(2))
.pipe(toConsole())
.on('finish', () => console.log("done"));

console.log("start");
```

>     start
>     6
>     11
>     18
>     done

In the above code, the calls to `fromIter()`, `times()`, and `toConsole()` create *real*, honest-to-goodness Node streams: streams3 streams, in fact, straight from the `readable-stream` package.  But on the inside, they're hooked up to generator functions, that can not only yield to `this.write()` etc., but to promises, thunks, or other generator functions.  (You can use all the async yielding goodness of `co`, `thunks`, or any other coroutine wrapper library you like, in fact, as long as it supports yielding to thunks.)

And because these are true Node streams, that means you can write gulp plugins as easy as this (JS):

```es6
module.exports = require('yieldable-streams').Duplex.factory(
    function* (options) { // plugin options
        var file;
        while ((file = yield this.read()) != null) {  // get a file
            console.log(file.path);  // do things with it
            yield this.write(file);  // pass it downstream
        }
    }
)
```
Or this (CoffeeScript):

<!-- mockdown: ++ignore -->

```coffee
module.exports = require('yieldable-streams').Duplex.factory (options) ->
    while (file = yield @read())?
        console.log file.path
        yield @write(file)
    return
```

## Usage

Using `ys = require('yieldable-streams')` to get the module, you can access the following classes:

* `ys.Readable` - class to create readable streams
* `ys.Writable` - class to create writable streams
* `ys.Duplex` - class to create duplex streams

Each class works *just like* the corresponding `readable-stream` class, except for two extra methods.  The first extra method, on the instances, is the `spi()` method, which returns a "stream provider interface" object, for use with generator functions.

This "stream provider interface" object has (some or all of) the following methods:

* `read()` -- return a thunk for the next value written to the stream (`Writable` and `Duplex` streams only).  If stream input has ended, the thunk will yield a null or undefined value.  If a stream that is piped into the current stream fires an error event, that error will be received instead of the data, causing an exception at the point of `yield this.read()`

* `write(data)` -- `push()` data onto the stream, returning a thunk that will fire when the stream is ready for more output (`Readable` and `Duplex` streams only).

* `end(err)` -- end the stream, optionally with an error object to emit as an `"error"` event (all stream types).

Each stream class also has a static method, `.factory(opts?, fn)`, which wraps the given function in such a way that when called, it will receive a stream provider interface as `this`, and will return the matching stream.  In this way, the function provides the stream's internal implementation, while the caller receives an ordinary stream object.

If `fn` is already wrapped by a coroutine library, such that it returns a thenable, promise or thunk, that return value will be hooked up to the `end()` method, so that unhandled exceptions will result in an `"error"` event, and a normal end to the coroutine will simply close the stream.  For example:

<!-- mockdown: ++ignore -->

```es6
aFactory = Writable.factory(
  co.wrap(
    function *(options) {
      /* 
        This generator will be run by `co`, but its `this`
        will still be the stream's spi(), so you can still
        `yield this.read()`.  If the generator throws an
        uncaught exception, it will become an error event
        on the stream.  Otherwise, the stream will `finish`
        when the generator ends, unless you `this.end()`
        it first.
       
        Of course, for this to work, the library you use
        to do the wrapping must return a promise or a
        thunk (node-style callback-taking function) when
        called, it must allow you to yield to thunks and
        receive the corresponding 
      */
    }
  )
)
```

If `fn`, however, returns a generator or is a generator function (i.e., it has *not* already been wrapped by a coroutine library, then `yieldable-streams` will wrap it using the `thunks` library.  (Lazily-loaded, to minimize overhead if you're not using it.)

The optional `opts` object contains the `readable-stream` options that the factory will use to create the stream.  If unsupplied, it will default to `{objectMode: true}`, thereby creating an object stream suitable for use with, e.g. gulp.  See the [Node streams documentation](https://nodejs.org/api/stream.html) for information on the possible options for each stream type.