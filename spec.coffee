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

{Readable, Writable, Duplex} = ys = require './'

rs = require 'readable-stream'

util = require 'util'

items = (val) -> Object.keys(val).map (k) -> [k, val[k]]

withSpy = (ob, name, fn) ->
    s = spy.named name, ob, name
    try fn(s) finally s.restore()

checkTE = (fn, msg) -> fn.should.throw TypeError, msg

shouldCallLaterOnce = (done, spy, args...) ->
    setImmediate failSafe done, -> onceExactly(spy, args...); done()

onceExactly = (spy, args...) ->
    spy.should.have.been.calledOnce
    spy.should.have.been.calledWithExactly(args...)




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
                it "that errors when a piped stream emits an error", (done) ->
                    ss = new Readable(objectMode: yes); ss.pipe(@s)
                    @spi.read() s = spy.named 'thunk', ->
                    @spi.read() s   # check pre-queued read case!
                    ss.emit("error", e=new Error)
                    shouldCallLaterOnce(done, s, e, null)

                it "that resolves to null after .end() is called", (done) ->
                    @s.end()
                    @spi.read() s = spy.named 'thunk', ->
                    s.should.not.have.been.called   # must be async
                    shouldCallLaterOnce(done, s, null, null)

                describe "that resolves when data is written to the stream", ->

                    shouldReadTwice = (done, s, d1, d2) ->
                        setImmediate failSafe done, ->
                            s.should.be.calledTwice
                            s.should.be.calledWithExactly(null, same(d1))
                            s.should.be.calledWithExactly(null, same(d2))
                            s.args[0][1].should.equal d1
                            done()

                    it "before .read() is called (once)", (done) ->
                        @s.write(data = thing: 5)
                        @spi.read() s = spy.named 'thunk', ->
                        shouldCallLaterOnce(done, s, null, same(data))

                    it "before .read() is called (multi)", (done) ->
                        @s.write(d1 = thing: 5); @s.write(d2 = thing: 6)
                        @spi.read() s = spy.named 'thunk', ->
                        @spi.read() s
                        shouldReadTwice(done, s, d1, d2)

                    it "after .read() is called", (done) ->
                        @spi.read() s = spy.named 'thunk', ->
                        process.nextTick => @s.write(d)
                        shouldCallLaterOnce(done, s, null, same(d = thing: 7))

                    it "after .read() is called (multi)", (done) ->
                        @spi.read() s = spy.named 'thunk', ->
                        @spi.read() s
                        process.nextTick => @s.write(d1); @s.write(d2)
                        shouldReadTwice(done, s, d1 = thing: 8, d2 = thing: 9)

                    it "before and after .read() is called", (done) ->
                        @spi.read() s = spy.named 'thunk', ->
                        @s.write(d1 = thing: 8)
                        @spi.read() s
                        @s.write(d2 = thing: 9)
                        shouldReadTwice(done, s, d1, d2)



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

                it "returns process.nextTick if buffer space is available", ->
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








    describe "#{clsName}.factory(opts?, fn) returns a function that", ->

        it "returns a #{clsName} created w/opts or {objectMode: true}", ->
            s1 = cls.factory(->)()
            s2 = cls.factory({}, ->)()
            s1.should.be.instanceOf(cls)
            s2.should.be.instanceOf(cls)
            expect(s1._readableState.objectMode).to.be.true if readable
            expect(s1._writableState.objectMode).to.be.true if writable
            expect(s2._readableState.objectMode).to.be.false if readable
            expect(s2._writableState.objectMode).to.be.false if writable

        it "invokes fn with stream.spi() as `this`, passing thru arguments", ->
            s = cls.factory(fn = spy.named 'fn', ->)(1, 2, 3)
            fn.should.be.calledOn(s.spi())
            fn.should.be.calledWithExactly(1, 2, 3)

        describe "executes fn's return value", ->
            checkEnd = (cb, s, t, inVal, outArgs...) ->
                s.should.not.be.called; t.should.be.calledOnce
                cb(inVal); s.should.be.calledOnce.and.calledWithExactly(outArgs...)
                t.reset()

            beforeEach -> @setup = (result) ->
                @stream = cls.factory(-> result)()
                @stream.on 'error', ->
                @spi = @stream.spi()
                return spy.named 'end', @spi, 'end'

            it "chains `then()` to call `end()` if it's a promise", ->
                s = @setup then: t = spy.named 'then', (@cb1, @cb2) =>
                checkEnd(@cb1, s, t, 1)
                s = @setup then: t
                checkEnd(@cb2, s, t, e=new Error, e)

            it "chains thunk to call `end()` if it's a function", ->
                s = @setup t = spy.named 'thunk', (@done) =>
                checkEnd(@done, s, t, null, null)
                s = @setup t
                checkEnd(@done, s, t, e=new Error, e)

            describe "via `thunks` if it's a generator", ->

                it "when the generator finishes without error", (done) ->
                    s = @setup(
                        called: no
                        next: ->
                            if @called then done: yes, value: undefined
                            else @called = yes; done: no, value: process.nextTick
                        throw: ->
                    )
                    shouldCallLaterOnce(done, s, null)

                it "when the generator finishes with error", (done) ->
                    e = new Error()
                    s = @setup(
                        called: no
                        next: ->
                            if @called then throw e
                            else
                                @called = yes
                                return done: no, value: process.nextTick
                        throw: ->
                    )
                    shouldCallLaterOnce(done, s, same(e))




checkAny('Readable', Readable, yes, no)
checkAny('Writable', Writable, no, yes)
checkAny('Duplex', Duplex, yes, yes)

require('mockdown').testFiles(['README.md'], describe, it, skip: no, globals:
    require: (arg) -> if arg is 'yieldable-streams' then ys else require(arg)
)






