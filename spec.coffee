{expect, should} = chai = require 'chai'
should = should()
chai.use require 'sinon-chai'

{spy} = sinon = require 'sinon'

same = sinon.match.same

spy.named = (name, args...) ->
    s = if this is spy then spy(args...) else this
    s.displayName = name
    return s

{Readable, Writable, Duplex} = require './'
rs = require 'readable-stream'

util = require 'util'

items = (val) -> Object.keys(val).map (k) -> [k, val[k]]

withSpy = (ob, name, fn) ->
    s = spy.named name, ob, name
    try fn(s) finally s.restore()

checkTE = (fn, msg) -> fn.should.throw TypeError, msg
















checkAny = (clsName, cls, readable, writable) ->

    describe "#{clsName}(opts?)", ->
        it "returns an instance of readable-stream.#{clsName}", ->
            expect(new cls()).to.be.instanceOf rs[clsName]

        it "passes opts through to readable-stream.#{clsName}", ->
            inst = new cls(objectMode: true)
            expect(inst._readableState.objectMode).to.be.true if readable
            expect(inst._writableState.objectMode).to.be.true if writable

        it "works without new", ->
            inst = cls(objectMode: true)
            expect(inst).to.be.instanceOf cls
            expect(inst).to.be.instanceOf rs[clsName]
            expect(inst._readableState.objectMode).to.be.true if readable
            expect(inst._writableState.objectMode).to.be.true if writable

        describe ".spi()", ->

            if writable then describe ".read() returns a thunk", ->
                it "that resolves when data is written to the stream"
                it "that errors when a piped stream emits an error"

            if readable then describe ".write(data)", ->
                it "sends data to the stream's push() method"
                it "returns a thunk that resolves when data is read"

            describe ".end(err?)", ->
                it "emits `err` as an error event"
                if readable then it "calls stream.push(null)"
                if writable then it "calls stream.end()"

    describe "#{clsName}.factory(opts?, fn) returns a function that", ->

        it "returns a #{clsName} created w/opts or {objectMode: true}"

        it "invokes fn with the stream.spi() as `this`, passing thru arguments"

        describe "executes fn's return value", ->
            it "chains `then()` to call `end()` if it's a promise"
            it "chains thunk to call `end()` if it's a function"
            it "via `thunks` if it's a generator"
        

checkAny('Readable', Readable, yes, no)
checkAny('Writable', Writable, no, yes)
checkAny('Duplex', Duplex, yes, yes)

require('mockdown').testFiles(['README.md'], describe, it, skip: yes)


