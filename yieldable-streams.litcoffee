# yieldable-streams

    rs = require 'readable-stream'
    redefine = require('redefine').using configurable: yes
    autocreate = require 'autocreate'

## The Stream Provider Interface

    base_mixin =
        spi: ->
            spi = {}
            me = this
            ['read', 'write', 'end'].forEach (key) ->
                if method = me["_spi_"+key]
                    spi[key] = -> method.apply(me, arguments)
            @spi = -> spi
            return spi

        _spi_end: (err) ->
            @emit('error', err) if err
            @end() if @_spi_read
            @push(null) if @_spi_write
            return

### Writable/Duplex Streams

    writable_mixin =
        __init__: ->
        _write: (data, enc, done) ->
        _spi_read: ->

### Readable/Duplex Streams

    readable_mixin =
        _spi_write: (data) ->

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















