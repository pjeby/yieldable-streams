# yieldable-streams

This module implements enhanced `readable-stream` derivatives that provide
an inverted API for use with generator-based coroutines.  `redefine` is used
to do mixins and lazy properties (such as callback queues), and `autocreate`
is used to make the classes instantiable without `new`, like Node core streams.
The `thunks` module is lazily-loaded to wrap generators if needed.

    rs = require 'readable-stream'
    redefine = require('redefine')
    autocreate = require 'autocreate'
    thunks = -> (thunks = require('thunks')()).apply(this, arguments)

## The Stream Provider Interface

Each stream class has an `.spi()` method that returns a "stream provider
interface" -- an object with `.read()` and/or `.write()` methods, and an
`.end()` method.  These are the inverse of the methods on the stream itself:
for example, `stream.spi().write()` emits data from a `Readable` or `Duplex`
stream, that will be readable via `stream.read()`.

The `spi()` method is actually a lazy property, so that whenever the method is
called, it will actually return the same object.

    base_mixin =
        spi: redefine.later ->
            spi = {}; me = this
            ['read', 'write', 'end'].forEach (key) ->
                if method = me["_spi_"+key]
                    spi[key] = -> method.apply(me, arguments)
            return -> spi   # always return the same object

The `.spi().end(err?)` method ends both possible sides of a stream, optionally
emitting an error as it does so.

        _spi_end: (err) ->
            @emit('error', err) if err
            @push(null) if @_spi_write
            @end() if @_spi_read
            return

### Writable/Duplex Streams

Writable streams pass on errors from streams piped into them, and therefore
have to buffer errors as well as data.  They also need to track the callback
provided by incoming `stream.write()` calls (as `.wreq`), so that the stream
can resume accepting writes when the data is actually read.

    writable_mixin =
        dbuf: redefine.later(Array)     # (err, data) buffer
        rreq: redefine.later(Array)     # spi.read() request callbacks

        __init__: ->
            @wreq = undefined   # incoming write request callback
            @on 'pipe', (s) => s.on 'error', (e) => @_tpush(null, null, e)
            @once 'prefinish', => @_tpush(null, null, null)  # queue null @ EOF

        _write: (data, enc, done) -> @_tpush(done, data)

        _tpush: (done, data, err) ->
            if rr = @rreq.shift()   # read() thunk waiting?
                rr(err ? null, data)
            else
                @dbuf.push(err ? null, data)    # nope, gotta buffer it

            # resume synchronously if another read() is pending
            if done then (if @rreq.length then done() else @wreq = done)
            return

        _spi_read: -> (done) =>
            if @_writableState.finished or @dbuf.length
                d1 = if @dbuf.length then @dbuf.shift() else null
                d2 = if @dbuf.length then @dbuf.shift() else null
                process.nextTick -> done(d1, d2)
            else
                @rreq.push(done)
            if @wreq
                process.nextTick(@wreq)     # resume calls to _write()
                @wreq = undefined
            return


### Readable/Duplex Streams

The readable aspect of a stream is simpler than the writable; only one callback
queue is needed, for `.spi().write()` calls that happen when the stream's
buffer is over the high water mark.  `.write()` returns `process.nextTick` if
the buffer has room, allowing the caller to proceed.

    readable_mixin =
        ww: redefine.later(Array)   # waiting writers' callbacks

        _read: -> @ww.shift()() if @ww.length

        _spi_write: (data, enc) ->
            if @push(data, enc) then process.nextTick else (done) => @ww.push(done)


### Transform Streams

Transform streams are basically Duplex streams with extra flow control.  But
because they use a different protocol (`_transform`/`_flush`), we have to
swap a few methods around, and make sure the base class's `_read()` and
`_write()` get called, while still working our own flow control magic.

    transform_mixin =
        __init__: ->
            @wreq = undefined   # incoming write request callback
            @on 'pipe', (s) => s.on 'error', (e) => @_tpush(null, null, e)
            # no need to trap 'prefinish'; Transform calls _flush for that

        _read:  ->
            readable_mixin._read.call(this) # unblock write()
            rs.Transform::_read.apply(this, arguments)  # do transform stuff

        _write: rs.Transform::_write

        _transform: writable_mixin._write
        _flush: (done) -> @_tpush(done, null, null)




## Stream Factories

A stream factory is a function wrapper that invokes a function with `this`
as the `.spi()` of a new stream of the corresponding type, passing through any
arguments given to the factory.  If options are given when creating the
factory, they're used to initialize the new streams.

    factory = (opts, fn) ->
        if typeof opts is "function"
            fn = opts
            opts = objectMode: yes

        return =>
            stream = new this(opts)
            gen = fn.apply(spi = stream.spi(), arguments)
            doEnd = (e) -> spi.end(e)

            if typeof gen?.then is "function"
                gen.then (-> spi.end()), doEnd
            else if typeof gen is "function"
                gen(doEnd)
            else if typeof gen?.next is "function"
                thunks.call(spi, gen)(doEnd)

            return stream
















## Exported Classes

    class exports.Readable extends rs.Readable
        Readable = autocreate this

        @factory = factory
        redefine @::, base_mixin
        redefine @::, readable_mixin

    class exports.Writable extends rs.Writable
        Writable = autocreate this
        constructor: -> super; @__init__()

        @factory = factory
        redefine @::, base_mixin
        redefine @::, writable_mixin

    class exports.Duplex extends rs.Duplex
        Duplex = autocreate this
        constructor: -> super; @__init__()

        @factory = factory
        redefine @::, base_mixin
        redefine @::, readable_mixin
        redefine @::, writable_mixin

    class exports.Transform extends rs.Transform
        Transform = autocreate this
        constructor: -> super; @__init__()

        @factory = factory
        redefine @::, base_mixin
        redefine @::, readable_mixin, configurable: yes
        redefine @::, writable_mixin, configurable: yes
        redefine @::, transform_mixin






## Utility Functions

`tap` is just a way to apply side-effects to an object and return the object;
it's not very performant, but it sure is convenient.

    tap = (ob, fn) -> fn.call(ob); ob


### Creating Combined Pipeline Streams

The `pipeline` facility combines a series of duplex or transform streams into
a single duplex stream, which will emit any errors emitted by its components.
It can optionally *not* do such error trapping, and also optionally skip piping
the streams together as well.  (Mostly, this is a convenience wrapper for things
you'd typically do with some streams before using `duplexify()` to create a
combined stream.

    exports.pipeline = (streams, opts) ->

        if !streams or streams.length == 0
            return exports.duplexify()  # non-readable, non-writable

        else if streams.length == 1
            return streams[0]

        [heads..., tail] = streams

        unless opts?.noPipe
            tail = streams.reduce (s1, s2) -> s1.pipe(s2)

        return tap exports.duplexify(heads[0], tail), -> unless opts?.noErr
            doErr = @emit.bind(this, 'error')
            stream.on('error', doErr) for stream in heads
            # duplexify will chain tail errors if the tail is readable; so if
            # it's not readable, we need to handle it here.
            tail.on('error', doErr) unless tail.readable





### Creating Duplex Streams from a Writable and Readable

    exports.duplexify = (head, tail) ->
        # Create a duplex stream

        tap exports.Duplex(opts =
            # that may or may not be read/write, depending on the sources
            writable: head?.writable ? no
            readable: tail?.readable ? no

            # and which matches the sources' respective object modes
            writableObjectMode: head?._writableState?.objectMode ? yes
            readableObjectMode: tail?._readableState?.objectMode ? yes

            # and string encodings
            defaultEncoding: head?._writableState?.defaultEncoding ? null
            encoding: encoding = tail?._readableState?.encoding ? null
        ), ->
            if opts.writable then exports.mirror(
                # Whose writable end writes to a pass-through readable
                # that's piped into the head of the pipeline
                this, tap(exports.Readable(objectMode:yes), -> @pipe(head))
            )
            if opts.readable then exports.mirror(
                # And whose readable end is written by a pass-through writable
                # that's piped from the tail of the pipeline
                tap(exports.Writable(objectMode:yes), -> tail.pipe(this)),
                this, encoding
            )

    exports.mirror = (src, dest, enc, done) ->
        src = src.spi()
        dest = dest.spi()
        do consume = -> src.read() (err, data) ->
            if err or data is null
                dest.end(err)
                done?(err)
            else
                dest.write(data, enc)(consume)


