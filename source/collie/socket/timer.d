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
module collie.socket.timer;

import core.memory;
import core.sys.posix.time;

import std.socket : socket_t;
import std.exception;

import collie.socket.common;
import collie.socket.eventloop;
import collie.utils.functional;

@trusted final class Timer : EventCallInterface
{
    this(EventLoop loop)
    {
        _loop = loop;
        _event = AsyncEvent.create(AsynType.TIMER, this);
    }

    ~this()
    {
		if (isActive){
			onClose();
        }
        AsyncEvent.free(_event);
    }

    pragma(inline, true) @property bool isActive() nothrow
    {
        return _event.isActive;
    }

    pragma(inline) void setCallBack(CallBack cback)
    {
        _callBack = cback;
    }

    bool start(ulong msesc)
    {
        if (isActive() || msesc <= 0)
            return false;
        static if (IOMode == IOMode.kqueue || CustomTimer)
        {
            _event.timeOut = cast(long) msesc;
        }
        else static if (IOMode == IOMode.epoll)
        {
            import collie.socket.selector.epoll;

            //  _timeout = msesc;
            _event.fd = cast(socket_t) timerfd_create(CLOCK_MONOTONIC, TFD_CLOEXEC | TFD_NONBLOCK);

            itimerspec its;
            ulong sec, nsec;
            sec = msesc / 1000;
            nsec = (msesc % 1000) * 1_000_000;
            its.it_value.tv_sec = cast(typeof(its.it_value.tv_sec)) sec;
            its.it_value.tv_nsec = cast(typeof(its.it_value.tv_nsec)) nsec;
            its.it_interval.tv_sec = its.it_value.tv_sec;
            its.it_interval.tv_nsec = its.it_value.tv_nsec;
            int err = timerfd_settime(_event.fd, 0, &its, null);
            if (err == -1)
            {
                import core.sys.posix.unistd;

                close(_event.fd);
                return false;
            }
        }
        return _loop.addEvent(_event);
    }

    pragma(inline) void stop()
    {
       onClose();
    }

protected:
    override void onRead() nothrow
    {
        static if (IOMode == IO_MODE.epoll)
        {
            import core.sys.posix.unistd;

            ulong value;
            read(_event.fd, &value, 8);
        }
        if (_callBack)
        {
			collectException(_callBack());
        }
        else
        {
            onClose();
        }
    }

    override void onWrite() nothrow
    {
    }

    override void onClose() nothrow
    {
		if(!isActive) return;
		_loop.delEvent(_event);
		static if (IOMode == IO_MODE.epoll)
        {
            import core.sys.posix.unistd;
            close(_event.fd);
			_event.fd = socket_t.init;
        } 
    }

private:
    // ulong _timeout;
    CallBack _callBack;
    AsyncEvent* _event = null;
    EventLoop _loop;
}

unittest
{
    import std.stdio;
    import std.datetime;

    EventLoop loop = new EventLoop();

    Timer tm = new Timer(loop);

    int cout = -1;
    ulong time;

    void timeout()
    {
        writeln("time  : ", Clock.currTime().toSimpleString());
        ++cout;
        if (cout == 0)
        {
            time = Clock.currTime().toUnixTime!long();
            return;
        }

        ++time;
        assert(time == Clock.currTime().toUnixTime!long());

        if (cout > 5)
        {
            writeln("loop stop!!!");
            tm.stop();
            loop.stop();
        }
    }

    tm.setCallBack(&timeout);

    tm.start(1000);

    loop.run();

}
