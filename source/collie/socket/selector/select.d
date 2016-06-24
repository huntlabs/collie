/*
 * Collie - An asynchronous event-driven network framework using Dlang development
 *
 * Copyright (C) 2015-2016  Shanghai Putao Technology Co., Ltd 
 *
 * Developer: putao's Dlang team
 *
 * Licensed under the Apache-2.0 License.
 *
 */

module collie.socket.selector.select;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.format;
import std.socket;
import std.experimental.logger;

import collie.socket.common;

//select 的定时器怎么实现？还要和socket 结合起来？
class SelectLoop
{
    bool addEvent(AsyncEvent* event) nothrow
    {
        return false;
    }

    bool modEvent(AsyncEvent* event) nothrow
    {
        return false;
    }

    bool delEvent(AsyncEvent* event) nothrow
    {
        return false;
    }

    void weakUp()
    {

    }

    void wait(int timeout)
    {
        /*       softUnittest({
        enum PAIRS = 768;
        version(Posix)
        () @trusted
        {
            enum LIMIT = 2048;
            static assert(LIMIT > PAIRS*2);
            import core.sys.posix.sys.resource;
            rlimit fileLimit;
            getrlimit(RLIMIT_NOFILE, &fileLimit);
            assert(fileLimit.rlim_max > LIMIT, "Open file hard limit too low");
            fileLimit.rlim_cur = LIMIT;
            setrlimit(RLIMIT_NOFILE, &fileLimit);
        } ();

        Socket[2][PAIRS] pairs;
        foreach (ref pair; pairs)
            pair = socketPair();
        scope(exit)
        {
            foreach (pair; pairs)
            {
                pair[0].close();
                pair[1].close();
            }
        }

        import std.random;
        auto rng = Xorshift(42);
        pairs[].randomShuffle(rng);

        auto readSet = new SocketSet();
        auto writeSet = new SocketSet();
        auto errorSet = new SocketSet();

        foreach (testPair; pairs)
        {
            void fillSets()
            {
                readSet.reset();
                writeSet.reset();
                errorSet.reset();
                foreach (ref pair; pairs)
                    foreach (s; pair[])
                    {
                        readSet.add(s);
                        writeSet.add(s);
                        errorSet.add(s);
                    }
            }

            fillSets();
            auto n = Socket.select(readSet, writeSet, errorSet);
            assert(n == PAIRS*2); // All in writeSet
            assert(writeSet.isSet(testPair[0]));
            assert(writeSet.isSet(testPair[1]));
            assert(!readSet.isSet(testPair[0]));
            assert(!readSet.isSet(testPair[1]));
            assert(!errorSet.isSet(testPair[0]));
            assert(!errorSet.isSet(testPair[1]));

            ubyte[1] b;
            testPair[0].send(b[]);
            fillSets();
            n = Socket.select(readSet, null, null);
            assert(n == 1); // testPair[1]
            assert(readSet.isSet(testPair[1]));
            assert(!readSet.isSet(testPair[0]));
            testPair[1].receive(b[]);
        }
    }); */
    }

private:
    AsyncEvent*[socket_t] _socketList;
}

private final class EventChannel : EventCallInterface
{
    this()
    {
        _pair = socketPair();
        _pair[0].blocking = false;
        _pair[1].blocking = false;
        _event = AsyncEvent.create(AsynType.EVENT, this, _pair[1].handle(), true, false,
            false);
    }

    ~this()
    {
        AsyncEvent.free(_event);
    }

    void doWrite() nothrow
    {
        try
        {
            _pair[0].send("wekup");
        }
        catch
        {
        }
    }

    override void onRead() nothrow
    {
        ubyte[128] data;
        while (true)
        {
            try
            {
                if (_pair[1].receive(data) <= 0)
                    return;
            }
            catch
            {
            }
        }
    }

    override void onWrite() nothrow
    {
    }

    override void onClose() nothrow
    {
    }

    Socket[2] _pair;
    AsyncEvent* _event;
}
