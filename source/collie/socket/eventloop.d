/* Copyright collied.org 
 */

module collie.socket.eventloop;

import core.thread;
import core.sync.mutex;
import core.memory;
import core.sync.mutex;

//public import std.concurrency;
import std.datetime;
import std.variant;
import std.algorithm.mutation;
import std.stdio;
import std.string;
import std.experimental.allocator.gc_allocator;

import collie.socket.common;
import collie.utils.queue;

/** 网络I/O处理的事件循环类
 @authors  Putao‘s Collie Team
 @date  2016.1
 */

class EventLoopImpl(T) if (is(T == class)) //用定义别名的方式
{
    this()
    {
        _poll = new T();
        _callbackList = Queue!(CallBack, true, false, GCAllocator)(32);
        _mutex = new Mutex();
        _run = false;
    }

    ~this()
    {
        _poll.destroy;
    }

    /** 开始执行事件等待。
	 @param :timeout = 无事件的超时等待时间。单位：毫秒
	 @note : 此函数可以多线程同时执行，实现多个线程共用一个事件调度。

	 */
    void run(int timeout = 100)
    {
        _thID = Thread.getThis.id();
        _run = true;
        while (_run)
        {
            _poll.wait(timeout);
            if (!_callbackList.empty)
            {
                doHandleList();
            }
        }
        _thID = 0;
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
        return _poll.addEvent(event);
    }

    bool modEvent(AsyncEvent* event) nothrow
    {
        if (event == null)
            return false;
        return _poll.modEvent(event);
    }

    bool delEvent(AsyncEvent* event) nothrow
    {
        if (event == null)
            return false;
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

        auto tmp = Queue!(CallBack, true, false, GCAllocator)(32);
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
                try
                {
                    error("\n\n----doHandleList erro ! erro : ", e.msg, "\n\n");
                }
                catch
                {
                }
            }
        }
    }

private:
    T _poll;
    Mutex _mutex;
    Queue!(CallBack, true, false, GCAllocator) _callbackList;
    bool _run;
    ThreadID _thID;
};

enum IO_MODE
{
    epoll,
    kqueue,
    iocp,
    select,
    poll,
    none
}

version (FreeBSD)
{
    import collie.socket.selector.kqueue;

    alias EventLoop = EventLoopImpl!(KqueueLoop);
    enum IO_MODE IOMode = IO_MODE.kqueue;
}
else version (OpenBSD)
{
    import collie.socket.selector.kqueue;

    alias EventLoop = EventLoopImpl!(KqueueLoop);
    enum IO_MODE IOMode = IO_MODE.kqueue;
}
else version (NetBSD)
{
    import collie.socket.selector.kqueue;

    alias EventLoop = EventLoopImpl!(KqueueLoop);
    enum IO_MODE IOMode = IO_MODE.kqueue;
}
else version (OSX)
{
    import collie.socket.selector.kqueue;

    alias EventLoop = EventLoopImpl!(KqueueLoop);
    enum IO_MODE IOMode = IO_MODE.kqueue;
}
else version (Solaris)
{
    public import collie.socket.selector.port;
}
else version (linux)
{
    import collie.socket.selector.epoll;

    alias EventLoop = EventLoopImpl!(EpollLoop);
    enum IO_MODE IOMode = IO_MODE.epoll;
}
else version (Posix)
{
    import collie.socket.selector.poll;
}
else
{
    import collie.socket.selector.select;
}
