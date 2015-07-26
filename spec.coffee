{expect, should} = chai = require 'chai'
should = should()
chai.use require 'sinon-chai'

{spy} = sinon = require 'sinon'

same = sinon.match.same

spy.named = (name, args...) ->
    s = if this is spy then spy(args...) else this
    s.displayName = name
    return s

failSafe = (done, fn) -> ->
    try fn.apply(this, arguments)
    catch e then done(e)

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

            beforeEach ->
                @s = cls(objectMode: yes, highWaterMark: 1)
                @spi = @s.spi()

            it "always returns the same object", ->
                expect(@s.spi()).to.equal @spi

            if writable then describe ".read() returns a thunk", ->
                it "that resolves when data is written to the stream"
                it "that errors when a piped stream emits an error"
                it "that always resolves to null after .end() is called"










            if readable then describe ".write(data)", ->

                it "sends data to the stream's push() method", ->
                    withSpy @s, 'push', (p) =>
                        @spi.write(data = thing:1)
                        p.should.have.been.calledOnce
                        p.should.have.been.calledWithExactly(same(data))

                it "returns a thunk that resolves when data is read", ->
                    @spi.write(data = thing:2) s = spy.named 'thunk', ->
                    s.should.not.have.been.called
                    @s.read()
                    s.should.have.been.calledOnce
                    s.should.have.been.calledWithExactly()
                    
                it "returns process.nextTick when buffer space is available", ->
                    spi = cls(objectMode: yes).spi()
                    expect(spi.write(data=thing:3)).to.equal process.nextTick























            describe ".end(err?)", ->

                it "emits `err` as an error event", (done) ->
                    @s.on 'error', s = spy.named 'error', ->
                    @spi.end(err = new Error)
                    setImmediate failSafe done, ->
                        s.should.have.been.calledOnce
                        s.should.have.been.calledWithExactly(same(err))
                        done()

                if readable then it "calls stream.push(null)", ->
                    withSpy @s, 'push', (p) =>
                        @spi.end()
                        p.should.have.been.calledOnce
                        p.should.have.been.calledWithExactly(null)

                if writable then it "calls stream.end()", ->
                    withSpy @s, 'end', (e) =>
                        @spi.end()
                        e.should.have.been.calledOnce
                        e.should.have.been.calledWithExactly()

                if readable and writable then it(
                    "calls stream.end() *after* stream.push()", ->
                        withSpy @s, 'end', (e) =>
                            withSpy @s, 'push', (p) =>
                                @spi.end()
                                e.should.have.been.calledOnce
                                e.should.have.been.calledWithExactly()
                                p.should.have.been.calledOnce
                                p.should.have.been.calledWithExactly(null)
                                e.should.have.been.calledAfter(p)
                )








        if writable then describe "._write(data, enc, done)", ->

            describe "when a read() thunk is outstanding,", ->
                it "calls back the thunk"
                it "forwards unhandled errors to done()"
                it "throws directly if no callback"
                it "calls done() synchronously if thunk calls read()"

            describe "without a read() thunk active,", ->
                it "queues the data for a later read()"


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












