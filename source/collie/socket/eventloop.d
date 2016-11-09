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
module collie.socket.eventloop;

import core.thread;
import core.sync.mutex;
import core.memory;

import std.exception;
import std.datetime;
import std.variant;
import std.algorithm.mutation;
import std.stdio;
import std.string;
import std.experimental.allocator.gc_allocator;

import collie.socket.common;
import collie.utils.queue;

static if (CustomTimer)
    import collie.utils.timingwheel;

/** 网络I/O处理的事件循环类
 @authors  Putao‘s Collie Team
 @date  2016.1
 */

@trusted class EventLoopImpl(T) if (is(T == class)) //用定义别名的方式
{
	alias CQueue = Queue!(CallBack,GCAllocator, true);
    this()
    {
        _poll = new T();
		_callbackList = CQueue(32);
        _mutex = new Mutex();
        _run = false;
        static if (CustomTimer)
            _timeWheel = new TimingWheel(CustomTimerWheelSize);
    }

    ~this()
    {
        _poll.destroy;
    }

    /** 开始执行事件等待。
	 @param :timeout = 无事件的超时等待时间。单位：毫秒,如果是用CustomTimer， 这个超时时间将无效。
	 @note : 此函数可以多线程同时执行，实现多个线程共用一个事件调度
	 */
    void run(int timeout = 100)
    {
        _thID = Thread.getThis.id();
        _run = true;
        static if (CustomTimer)
            _nextTime = (Clock.currStdTime() / 10000) + CustomTimerTimeOut;
        while (_run)
        {
            static if (CustomTimer)
                timeout = doWheel();
            _poll.wait(timeout);
            if (!_callbackList.empty)
            {
                doHandleList();
            }
        }
        _thID = ThreadID.init;
        _run = false;
    }

    //@property Channel[int] channelList(){return _channelList;}
    void weakUp()
    {
        _poll.weakUp();
    }

    bool isRuning() nothrow
    {
        return _run;
    }

    void stop()
    {
        if (isRuning())
        {
            _run = false;
            weakUp();
        }
    }

    bool isInLoopThread()
    {
        if (!isRuning())
            return true;
        return _thID == Thread.getThis.id;
    }

    void post(CallBack cback)
    {
        if (isInLoopThread())
        {
            cback();
            return;
        }
        else
        {
            synchronized (_mutex)
            {
                _callbackList.enQueue(cback);
            }
            weakUp();
        }
    }

    bool addEvent(AsyncEvent* event) nothrow
    {
        if (event == null)
            return false;
        static if (CustomTimer)
        {
            if (event.type() == AsynType.TIMER)
            {
                try
                {
                    CWheelTimer timer = new CWheelTimer(event);
                    _timeWheel.addNewTimer(timer, timer.wheelSize());
                    event.timer = timer;
                    event.isActive(true);
                }
                catch
                {
                    collectException(error("new CWheelTimer error!!!"));
                    return false;
                }
                return true;
            }
        }
        return _poll.addEvent(event);
    }

    bool modEvent(AsyncEvent* event) nothrow
    {
        if (event == null)
            return false;
        static if (CustomTimer)
        {
            if (event.type() == AsynType.TIMER)
                return false;
        }
        return _poll.modEvent(event);
    }

    bool delEvent(AsyncEvent* event) nothrow
    {
        if (event == null)
            return false;
        static if (CustomTimer)
        {
            if (event.type() == AsynType.TIMER)
            {
                event.timer.stop();
                try
                {
                    import collie.utils.memory;

                    gcFree(event.timer);
                }
                catch
                {
                }
                event.timer = null;
                event.isActive(false);
                return true;
            }
        }
        return _poll.delEvent(event);
    }

    @property loop() nothrow
    {
        return _poll;
    }

protected:
    void doHandleList()
    {
        import std.algorithm : swap;

		auto tmp = CQueue(32);
        synchronized (_mutex)
        {
            swap(tmp, _callbackList);
        }
        while (!tmp.empty)
        {
            try
            {
                auto fp = tmp.deQueue(null);
                fp();
            }
            catch (Exception e)
            {
				import collie.utils.exception;
				showException(e);
            }
        }
    }

private:
    T _poll;
    Mutex _mutex;
	CQueue _callbackList;
    bool _run;
    ThreadID _thID;
    static if (CustomTimer)
    {
        TimingWheel _timeWheel;
        long _nextTime;

        int doWheel()
        {
            auto nowTime = (Clock.currStdTime() / 10000);
            while (nowTime >= _nextTime)
            {
                _timeWheel.prevWheel();
                _nextTime += CustomTimerTimeOut;
                nowTime = (Clock.currStdTime() / 10000);
            }
            nowTime = _nextTime - nowTime;
            return cast(int) nowTime;
        }
    }
}

static if (IOMode == IO_MODE.kqueue)
{
    import collie.socket.selector.kqueue;

    alias EventLoop = EventLoopImpl!(KqueueLoop);
}
else static if (IOMode == IO_MODE.epoll)
{
    import collie.socket.selector.epoll;

    alias EventLoop = EventLoopImpl!(EpollLoop);
}
else static if (IOMode == IO_MODE.iocp)
{
    public import collie.socket.selector.iocp;

    alias EventLoop = EventLoopImpl!(IOCPLoop);
}
else
{
    import collie.socket.selector.select;

    alias EventLoop = EventLoopImpl!(SelectLoop);
}

static if (CustomTimer)
{
    pragma(msg, "use CustomTimer!!!!");
private:
	@trusted final class CWheelTimer : WheelTimer
    {
        this(AsyncEvent* event)
        {
            _event = event;
            auto size = event.timeOut / CustomTimerTimeOut;
            auto superfluous = event.timeOut % CustomTimerTimeOut;
            size += superfluous > CustomTimer_Next_TimeOut ? 1 : 0;
            size = size > 0 ? size : 1;
            _wheelSize = cast(uint) size;
            _circle = _wheelSize / CustomTimerWheelSize;
            trace("_wheelSize = ", _wheelSize, " event.timeOut = ", event.timeOut);
        }

        override void onTimeOut() nothrow
        {
            _now++;
            if (_now >= _circle)
            {
                _now = 0;
                rest(_wheelSize);
                _event.obj().onRead();
            }
        }

        pragma(inline, true) @property wheelSize()
        {
            return _wheelSize;
        }

    private:
        uint _wheelSize;
        uint _circle;
        uint _now = 0;
        AsyncEvent* _event;
    }
}
