{expect, should} = chai = require 'chai'
should = should()
chai.use require 'sinon-chai'

{spy} = sinon = require 'sinon'

same = sinon.match.same

spy.named = (name, args...) ->
    s = if this is spy then spy(args...) else this
    s.displayName = name
    return s

{Readable, Writable, Duplex, Transform, mirror, duplexify, pipeline } = ys =
    require './'

rs = require 'readable-stream'

util = require 'util'

items = (val) -> Object.keys(val).map (k) -> [k, val[k]]

withSpy = (ob, name, fn) ->
    s = spy.named name, ob, name
    try fn(s) finally s.restore()

checkTE = (fn, msg) -> fn.should.throw TypeError, msg

shouldCallLaterOnce = (spy, args...) ->
    yield setImmediate
    onceExactly(spy, args...)
    return

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
                it "that errors when a piped stream emits an error", ->
                    ss = new Readable(objectMode: yes); ss.pipe(@s)
                    @spi.read() s = spy.named 'thunk', ->
                    @spi.read() s   # check pre-queued read case!
                    ss.emit("error", e=new Error)
                    yield from shouldCallLaterOnce(s, e, null)

                it "that resolves to null after .end() is called", ->
                    @s.end()
                    @spi.read() s = spy.named 'thunk', ->
                    s.should.not.have.been.called   # must be async
                    yield from shouldCallLaterOnce(s, null, null)

                describe "that resolves when data is written to the stream", ->

                    shouldReadTwice = (s, d1, d2) ->
                        yield setImmediate
                        s.should.be.calledTwice
                        s.should.be.calledWithExactly(null, same(d1))
                        s.should.be.calledWithExactly(null, same(d2))
                        s.args[0][1].should.equal d1
                        return

                    it "before .read() is called (once)", ->
                        @s.write(data = thing: 5)
                        @spi.read() s = spy.named 'thunk', ->
                        yield from shouldCallLaterOnce(s, null, same(data))

                    it "before .read() is called (multi)", ->
                        @s.write(d1 = thing: 5); @s.write(d2 = thing: 6)
                        @spi.read() s = spy.named 'thunk', ->
                        @spi.read() s
                        yield from shouldReadTwice(s, d1, d2)

                    it "after .read() is called", ->
                        @spi.read() s = spy.named 'thunk', ->
                        process.nextTick => @s.write(d)
                        yield from shouldCallLaterOnce(s, null, same(d = thing: 7))

                    it "after .read() is called (multi)", ->
                        @spi.read() s = spy.named 'thunk', ->
                        @spi.read() s
                        process.nextTick => @s.write(d1); @s.write(d2)
                        yield from shouldReadTwice(s, d1 = thing: 8, d2 = thing: 9)

                    it "before and after .read() is called", ->
                        @spi.read() s = spy.named 'thunk', ->
                        @s.write(d1 = thing: 8)
                        @spi.read() s
                        @s.write(d2 = thing: 9)
                        yield from shouldReadTwice(s, d1, d2)



            if readable then describe ".write(data)", ->

                it "sends data to the stream's push() method", ->
                    withSpy @s, 'push', (p) =>
                        @spi.write(data = thing:1)
                        p.should.have.been.calledOnce
                        p.should.have.been.calledWithExactly(
                            same(data), undefined
                        )

                it "sends encoding to the stream's push() method", ->
                    withSpy @s, 'push', (p) =>
                        @spi.write("data", "utf8")
                        p.should.have.been.calledOnce
                        p.should.have.been.calledWithExactly("data", "utf8")


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

                it "emits `err` as an error event", ->
                    @s.on 'error', s = spy.named 'error', ->
                    @spi.end(err = new Error)
                    yield setImmediate
                    s.should.have.been.calledOnce
                    s.should.have.been.calledWithExactly(same(err))

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

                it "when the generator finishes without error", ->
                    s = @setup(
                        called: no
                        next: ->
                            if @called then done: yes, value: undefined
                            else @called = yes; done: no, value: process.nextTick
                        throw: ->
                    )
                    yield from shouldCallLaterOnce(s, null)

                it "when the generator finishes with error", ->
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
                    yield from shouldCallLaterOnce(s, same(e))




checkAny('Readable', Readable, yes, no)
checkAny('Writable', Writable, no, yes)
checkAny('Duplex', Duplex, yes, yes)
checkAny('Transform', Transform, yes, yes)









describe "Pipeline Utilities", ->

    fromArray = Readable.factory (array) ->
        for item in array
            yield @write(item)
        return

    toArray = (r) -> ->
        r.pipe(w = Writable(objectMode: yes))
        data = []
        read = w.spi().read
        while (item = yield read()) isnt null
            data.push(item)
        return data

    describe "mirror(src, dest, enc? done?)", ->

        it "`done` and `enc` are optional", ->
            [w, r] = [Writable(objectMode: yes), Readable(objectMode: yes)]
            fromArray([1,2,3]).pipe(w)
            res = toArray(r)
            mirror(w, r)
            expect(yield res).to.eql [1,2,3]

        it "`done` is called when stream finishes", ->
            [w, r] = [Writable(objectMode: yes), Readable(objectMode: yes)]
            fromArray([1,2,3]).pipe(w)
            res = toArray(r)
            yield (done) -> mirror(w, r, null, done)
            expect(yield res).to.eql [1,2,3]

        it "`enc` is used for encoding", ->
            [w, r] = [Writable(objectMode: yes), Readable()]
            fromArray(["61", "6263"]).pipe(w)
            res = toArray(r)
            yield (done) -> mirror(w, r, "hex", done)
            expect(yield res).to.eql [Buffer([0x61]), Buffer([0x62, 0x63])]




        it "mirrors errors from pipes into `src` and sends them to `done`", ->
            [w, r] = [Writable(), Readable()]
            (p = Readable()).pipe(w)
            emitted = no

            r.on "error", (e) ->
                expect(e).to.equal err
                emitted = yes
            p.spi().end(err = new Error("done"))

            try
                yield (done) -> mirror w, r, null, done
            catch e
                emitted.should.be.true
                expect(e).to.equal err
                return
            throw new AssertionError("Error wasn't sent to done")
























    describe "duplexify(writable, readable)", ->

        describe "pipes and mirrors each applicable side", ->

            beforeEach ->
                [@w, @r] = [Writable(), Readable()]
                @rpipe = spy @r, 'pipe'
                @w.on 'pipe', @wpipe = spy ->

                @check = (dup, ms, readable, writable) ->
                    if writable
                        @wpipe.should.be.calledOnce
                        headPass = @wpipe.args[0][0]
                        ms.should.be.calledWithExactly(same(dup), same(headPass))
                    else @wpipe.should.not.be.called

                    if readable
                        @rpipe.should.be.calledOnce
                        tailPass = @rpipe.args[0][0]
                        ms.should.be.calledWithExactly(
                            same(tailPass), same(dup), null
                        )
                    else @rpipe.should.not.be.called

                    dup.readable.should.equal readable
                    dup.writable.should.equal writable

            it "when both sides are available", ->
                withSpy ys, 'mirror', (ms) =>
                    dup = duplexify(@w, @r)
                    @check(dup, ms, yes, yes)
                    ms.should.be.calledTwice

            it "when neither side is available", ->
                withSpy ys, 'mirror', (ms) =>
                    dup = duplexify(@r, @w)
                    @check(dup, ms, no, no)
                    ms.should.not.be.called



            it "when only a writable is available", ->
                withSpy ys, 'mirror', (ms) =>
                    dup = duplexify(@w, @w)
                    @check(dup, ms, no, yes)
                    ms.should.be.calledOnce

            it "when only a readable is available", ->
                withSpy ys, 'mirror', (ms) =>
                    dup = duplexify(@r, @r)
                    @check(dup, ms, yes, no)
                    ms.should.be.calledOnce

        describe "matches", ->
            getOpts = (wo, ro) ->
                opts = null
                withSpy ys, 'Duplex', (Dup) ->
                    duplexify(Writable(wo), Readable(ro))
                    Dup.should.be.calledOnce
                    opts = Dup.args[0][0]
                return opts
                
            it "readable's objectMode", ->
                getOpts(null, null).readableObjectMode.should.be.false
                getOpts(null, objectMode: yes).readableObjectMode.should.be.true
                
            it "readable's encoding", ->
                expect(getOpts(null, null).encoding).to.not.exist
                expect(getOpts(null, encoding:"hex").encoding).to.equal "hex"
                
            it "writable's objectMode", ->
                getOpts(null, null).writableObjectMode.should.be.false
                getOpts(objectMode: yes).writableObjectMode.should.be.true
                
            it "writable's defaultEncoding", ->
                expect(getOpts(null, null).defaultEncoding).to.equal "utf8"
                expect(getOpts(defaultEncoding:"hex").defaultEncoding).to.equal "hex"





    describe "pipeline(streams, opts?)", ->

        it "pipes streams together by default", ->
            p = pipeline([s1 = Readable(), s2 = Transform(), s3 = Writable()])
            s1._readableState.pipes.should.equal s2
            s2._readableState.pipes.should.equal s3

        it "Doesn't pipe anything if `noPipe`", ->
            p = pipeline(
                [s1 = Readable(), s2 = Transform(), s3 = Writable()]
                noPipe: yes
            )
            expect(s1._readableState.pipes).to.equal null
            expect(s2._readableState.pipes).to.equal null

        it "Does error handling by default", ->
            p = pipeline([s1 = Readable(), s2 = Transform(), s3 = Writable()])
            p.on 'error', h = spy ->
            checkEmit = (s) ->
                s.emit 'error', e = new Error()
                h.should.be.calledWithExactly(same(e))
            checkEmit(s1)
            checkEmit(s2)
            checkEmit(s3)
            h.should.be.calledThrice
            
        it "Doesn't do error handling if `noErr`", ->
            p = pipeline(
                [s1 = Readable(), s2 = Transform(), s3 = Writable()]
                noErr: yes
            )
            p.on 'error', h = spy ->
            checkEmit = (s) ->
                s.on 'error', ->    # prevent uncaught error
                s.emit 'error', e = new Error()
                h.should.not.be.called
            checkEmit(s1)
            checkEmit(s2)
            checkEmit(s3)


        it "doesn't duplicate error handling on a readable tail", ->
            p = pipeline([s1 = Readable(), s2 = Transform(), s3 = Duplex()])
            p.on 'error', h = spy ->
            checkEmit = (s) ->
                s.emit 'error', e = new Error()
                h.should.be.calledWithExactly(same(e))
            checkEmit(s1)
            checkEmit(s2)
            checkEmit(s3)
            h.should.be.calledThrice

        it "Returns an unreadable, unwritable stream if no streams", ->
            p = pipeline([])
            p.readable.should.be.false
            p.writable.should.be.false
            p.should.be.instanceOf Duplex

        it "Returns original stream if length is 1", ->
            p = pipeline([s=Duplex()])
            p.should.equal s


require('mockdown').testFiles(['README.md'], describe, it, skip: no, globals:
    require: (arg) -> if arg is 'yieldable-streams' then ys else require(arg)
)
















