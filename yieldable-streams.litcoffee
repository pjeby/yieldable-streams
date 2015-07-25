# yieldable-streams

    rs = require 'readable-stream'
    redefine = require('redefine').using configurable: yes
    autocreate = require 'autocreate'

    base_mixin = __init__: ->
    readable_mixin = {}
    writable_mixin = __init__: ->

    factory = ->

## Exported Classes

    class exports.Readable extends rs.Readable
        Readable = autocreate this
        constructor: -> super; @__init__()

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

