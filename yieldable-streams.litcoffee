# yieldable-streams

This module implements enhanced `readable-stream` derivatives that provide
an inverted API for use with generator-based coroutines.  `redefine` is used
to do mixins and lazy properties (such as callback queues), and `autocreate`
is used to make the classes instantiable without `new` (the way Node core
streams are.)

    rs = require 'readable-stream'
    redefine = require('redefine')
    autocreate = require 'autocreate'

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
            spi = {}
            me = this
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

    writable_mixin =
        __init__: ->
        _write: (data, enc, done) ->
        _spi_read: ->


### Readable/Duplex Streams

The readable aspect of a stream is simpler than the writable; only one callback
queue is needed, for `.spi().write()` calls that happen when the stream's
buffer is over the high water mark.  `.write()` returns `process.nextTick` if
the buffer has room, allowing the caller to proceed.

    readable_mixin =
        ww: redefine.later(Array)   # waiting writers' callbacks
        
        _read: -> @ww.shift()() if @ww.length

        _spi_write: (data) ->
            if @push(data) then process.nextTick else (done) => @ww.push(done)
        


















## Stream Factories

    factory = ->

## Exported Classes

    class exports.Readable extends rs.Readable
        Readable = autocreate this
        constructor: -> super; @__init__?()

        @factory = factory
        redefine @::, base_mixin
        redefine @::, readable_mixin

    class exports.Writable extends rs.Writable
        Writable = autocreate this
        constructor: -> super; @__init__?()

        @factory = factory
        redefine @::, base_mixin
        redefine @::, writable_mixin

    class exports.Duplex extends rs.Duplex
        Duplex = autocreate this
        constructor: -> super; @__init__?()

        @factory = factory
        redefine @::, base_mixin
        redefine @::, readable_mixin
        redefine @::, writable_mixin











