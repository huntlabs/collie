/*
 * Collie - An asynchronous event-driven network framework using Dlang development
 *
 * Copyright (C) 2015-2017  Shanghai Putao Technology Co., Ltd 
 *
 * Developer: putao's Dlang team
 *
 * Licensed under the Apache-2.0 License.
 *
 */
module collie.net.eventloopgroup;

import core.thread;
import std.parallelism;

import kiss.event;

@trusted final class EventLoopGroup
{
    this(uint size = (totalCPUs - 1), int waitTime = 2000)
    {
        size = size > 0 ? size : 1;
        foreach (i; 0 .. size)
        {
            auto loop = new GroupMember(new EventLoop);
            _loops[loop] = new Thread(&loop.start);
        }
    }
 
    void start()
    {
        if (_started)
            return;
        foreach (ref t; _loops.values)
        {
            t.start();
        }
        _started = true;
    }

    void stop()
    {
        if (!_started)
            return;
        foreach (ref loop; _loops.keys)
        {
            loop.stop();
        }
        _started = false;
        wait();
    }

    @property length()
    {
        return _loops.length;
    }

    void addEventLoop(EventLoop lop, int waitTime = 2000)
    {
        auto loop = new GroupMember(lop);
        auto th = new Thread(&loop.start);
        _loops[loop] = th;
        if (_started)
            th.start();
    }

    EventLoop opIndex(size_t index)
    {
        return at(index);
    }

    EventLoop at(size_t index)
    {
        auto loops = _loops.keys;
        auto i = index % cast(size_t) loops.length;
        return loops[i].eventLoop;
    }

    void wait()
    {
        foreach (ref t; _loops.values)
        {
            t.join(false);
        }
    }

	int opApply(scope int delegate(EventLoop) dg)
    {
        int ret = 0;
        foreach (ref loop; _loops.keys)
        {
            ret = dg(loop.eventLoop);
            if (ret)
                break;
        }
        return ret;
    }

private:
    bool _started;
    Thread[GroupMember] _loops;
}

private:

final class GroupMember
{
    this(EventLoop loop)
    {
        _loop = loop;
    }

    void start()
    {
        _loop.join();
    }

    alias eventLoop this;

    @property eventLoop()
    {
        return _loop;
    }

private:
    EventLoop _loop;
}
