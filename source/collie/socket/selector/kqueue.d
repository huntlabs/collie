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

module collie.socket.selector.kqueue;

import collie.socket.common;

static if (IOMode == IO_MODE.kqueue)
{

    import core.stdc.errno;
    import core.sys.posix.sys.types; // for ssize_t, size_t
    import core.sys.posix.netinet.tcp;
    import core.sys.posix.netinet.in_;
    import core.sys.posix.time;
    import core.sys.posix.unistd;

    import std.exception;
    import std.socket;

    import collie.utils.vector;

    class KqueueLoop
    {
        this()
        {
            if ((_efd = kqueue()) < 0)
            {
                errnoEnforce("kqueue failed");
            }
            _event = new EventChannel();
            addEvent(_event._event);
        }

        ~this()
        {
            .close(_efd);
            _event.destroy;
        }

        /** 添加一个Channel对象到事件队列中。
            @param   socket = 添加到时间队列中的Channel对象，根据其type自动选择需要注册的事件。
            @return true 添加成功, false 添加失败，并把错误记录到日志中.
            */
        bool addEvent(AsyncEvent* event) nothrow
        {
            int err = 0;
            if (event.type() == AsynType.TIMER)
            {
                kevent_t ev;
                event.timeOut = event.timeOut < 20 ? 20 : event.timeOut;
                event.fd = getTimerfd();
                EV_SET(&ev, event.fd, EVFILT_TIMER,
                    EV_ADD | EV_ENABLE | EV_CLEAR, 0, event.timeOut, event); //单位毫秒
                err = kevent(_efd, &ev, 1, null, 0, null);
            }
            else if (event.enRead && event.enWrite)
            {
                kevent_t[2] ev = void;
                short read = EV_ADD | EV_ENABLE;
                short write = EV_ADD | EV_ENABLE;
                if (event.etMode)
                {
                    read |= EV_CLEAR;
                    write |= EV_CLEAR;
                }
                EV_SET(&(ev[0]), event.fd, EVFILT_READ, read, 0, 0, event);
                EV_SET(&(ev[1]), event.fd, EVFILT_WRITE, write, 0, 0, event);
                err = kevent(_efd, &(ev[0]), 2, null, 0, null);
            }
            else if (event.enRead)
            {
                kevent_t ev;
                short read = EV_ADD | EV_ENABLE;
                if (event.etMode)
                    read |= EV_CLEAR;
                EV_SET(&ev, event.fd, EVFILT_READ, read, 0, 0, event);
                err = kevent(_efd, &ev, 1, null, 0, null);
            }
            else if (event.enWrite)
            {
                kevent_t ev;
                short write = EV_ADD | EV_ENABLE;
                if (event.etMode)
                    write |= EV_CLEAR;
                EV_SET(&ev, event.fd, EVFILT_WRITE, write, 0, 0, event);
                err = kevent(_efd, &ev, 1, null, 0, null);
            }
            else
            {
                return false;
            }

            if (err < 0)
            {
                return false;
            }

            event.isActive = true;
            return true;
        }

        bool modEvent(AsyncEvent* event) nothrow
        {
            int err = 0;
            if (event.type() != AsynType.TCP && event.type() != AsynType.UDP)
            {
                return false;
            }

            kevent_t[2] ev = void;
            short read = EV_ADD | EV_ENABLE;
            short write = EV_ADD | EV_ENABLE;
            if (event.etMode)
            {
                read |= EV_CLEAR;
                write |= EV_CLEAR;
            }
            if (event.enRead)
            {
                EV_SET(&ev[0], event.fd, EVFILT_READ, read, 0, 0, event);
            }
            else
            {
                EV_SET(&ev[0], event.fd, EVFILT_READ, EV_DELETE, 0, 0, event);
            }

            if (event.enWrite)
            {
                EV_SET(&ev[1], event.fd, EVFILT_WRITE, write, 0, 0, event);
            }
            else
            {
                EV_SET(&ev[1], event.fd, EVFILT_WRITE, EV_DELETE, 0, 0, event);
            }
            kevent(_efd, ev.ptr, 2, null, 0, null);
            event.isActive = true;
            return true;
        }

        /** 从epoll队列中移除Channel对象。
            @param socket = 需要移除的Channel对象
            @return (true) 移除成功, (false) 移除失败，并把错误输出到控制台.
            */
        bool delEvent(AsyncEvent* event) nothrow
        {
            int err = 0;
            if (event.type() == AsynType.TIMER)
            {
                kevent_t ev;
                EV_SET(&ev, event.fd, EVFILT_TIMER, EV_DELETE, 0, 0, event);
                err = kevent(_efd, &ev, 1, null, 0, null);
            }
            else if (event.enRead && event.enWrite)
            {
                kevent_t[2] ev = void;
                EV_SET(&(ev[0]), event.fd, EVFILT_READ, EV_DELETE, 0, 0, event);
                EV_SET(&(ev[1]), event.fd, EVFILT_WRITE, EV_DELETE, 0, 0, event);
                err = kevent(_efd, &(ev[0]), 2, null, 0, null);
            }
            else if (event.enRead)
            {
                kevent_t ev;
                short read = EV_ADD | EV_ENABLE;
                EV_SET(&ev, event.fd, EVFILT_READ, EV_DELETE, 0, 0, event);
                err = kevent(_efd, &ev, 1, null, 0, null);
            }
            else if (event.enWrite)
            {
                kevent_t ev;
                short write = EV_ADD | EV_ENABLE;
                if (event.etMode)
                    write |= EV_CLEAR;
                EV_SET(&ev, event.fd, EVFILT_WRITE, EV_DELETE, 0, 0, event);
                err = kevent(_efd, &ev, 1, null, 0, null);
            }
            else
            {
                return false;
            }

            event.isActive = false;
            return true;
        }

        /** 调用epoll_wait。
            *    @param    timeout = epoll_wait的等待时间
            *    @param    eptr   = epoll返回时间的存储的数组指针
            *    @param    size   = 数组的大小
            *    @return 返回当前获取的事件的数量。
            */

        void wait(int timeout)
        {
            auto tm = timeout % 1000;
            auto tspec = timespec(timeout / 1000, tm * 1000 * 1000);
            kevent_t event;
            auto num = kevent(_efd, null, 0, &event, 1, &tspec);
            if (num <= 0)
                return;
            auto ev = cast(AsyncEvent*) event.udata;

            if ((event.flags & EV_EOF) || (event.flags & EV_ERROR))
            {
                ev.obj.onClose();
                return;
            }

            if (ev.type() == AsynType.TIMER)
            {
                ev.obj.onRead();
                return;
            }

            if (event.filter & EVFILT_WRITE)
            {
                ev.obj.onWrite();
            }
            if (event.filter & EVFILT_READ)
            {
                ev.obj.onRead();
            }
        }

        void weakUp() nothrow
        {
            _event.doWrite();
        }

    private:
        /** 存储 epoll的fd */
        int _efd;
        EventChannel _event;
    }

    static this()
    {
        import core.sys.posix.signal;

        signal(SIGPIPE, SIG_IGN);
    }

    private final class EventChannel : EventCallInterface
    {
        this()
        {
            _pair = socketPair();
            _pair[0].blocking = false;
            _pair[1].blocking = false;
            _event = AsyncEvent.create(AsynType.EVENT, this,
                _pair[1].handle(), true, false, false);
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

    auto getTimerfd()
    {
        import core.atomic;

        static shared int i = int.max;
        atomicOp!"-="(i, 1);
        if (i < 655350)
            i = int.max;
        return cast(socket_t) i;
    }

extern (C):
@nogc:
nothrow:

    enum : short
    {
        EVFILT_READ = -1,
        EVFILT_WRITE = -2,
        EVFILT_AIO = -3, /* attached to aio requests */
        EVFILT_VNODE = -4, /* attached to vnodes */
        EVFILT_PROC = -5, /* attached to struct proc */
        EVFILT_SIGNAL = -6, /* attached to struct proc */
        EVFILT_TIMER = -7, /* timers */
        EVFILT_MACHPORT = -8, /* Mach portsets */
        EVFILT_FS = -9, /* filesystem events */
        EVFILT_USER = -10, /* User events */
        EVFILT_VM = -12, /* virtual memory events */
        EVFILT_SYSCOUNT = 11
    }

    extern (D) void EV_SET(kevent_t* kevp, typeof(kevent_t.tupleof) args)
    {
        *kevp = kevent_t(args);
    }

    struct kevent_t
    {
        uintptr_t ident; /* identifier for this event */
        short filter; /* filter for event */
        ushort flags;
        uint fflags;
        intptr_t data;
        void* udata; /* opaque user data identifier */
    }

    enum
    {
        /* actions */
        EV_ADD = 0x0001, /* add event to kq (implies enable) */
        EV_DELETE = 0x0002, /* delete event from kq */
        EV_ENABLE = 0x0004, /* enable event */
        EV_DISABLE = 0x0008, /* disable event (not reported) */

        /* flags */
        EV_ONESHOT = 0x0010, /* only report one occurrence */
        EV_CLEAR = 0x0020, /* clear event state after reporting */
        EV_RECEIPT = 0x0040, /* force EV_ERROR on success, data=0 */
        EV_DISPATCH = 0x0080, /* disable event after reporting */

        EV_SYSFLAGS = 0xF000, /* reserved by system */
        EV_FLAG1 = 0x2000, /* filter-specific flag */

        /* returned values */
        EV_EOF = 0x8000, /* EOF detected */
        EV_ERROR = 0x4000, /* error, data contains errno */
    
}

enum
{
    /*
        * data/hint flags/masks for EVFILT_USER, shared with userspace
        *
        * On input, the top two bits of fflags specifies how the lower twenty four
        * bits should be applied to the stored value of fflags.
        *
        * On output, the top two bits will always be set to NOTE_FFNOP and the
        * remaining twenty four bits will contain the stored fflags value.
        */
    NOTE_FFNOP = 0x00000000, /* ignore input fflags */
    NOTE_FFAND = 0x40000000, /* AND fflags */
    NOTE_FFOR = 0x80000000, /* OR fflags */
    NOTE_FFCOPY = 0xc0000000, /* copy fflags */
    NOTE_FFCTRLMASK = 0xc0000000, /* masks for operations */
    NOTE_FFLAGSMASK = 0x00ffffff,

    NOTE_TRIGGER = 0x01000000, /* Cause the event to be
                                    triggered for output. */

    /*
        * data/hint flags for EVFILT_{READ|WRITE}, shared with userspace
        */
    NOTE_LOWAT = 0x0001, /* low water mark */

    /*
        * data/hint flags for EVFILT_VNODE, shared with userspace
        */
    NOTE_DELETE = 0x0001, /* vnode was removed */
    NOTE_WRITE = 0x0002, /* data contents changed */
    NOTE_EXTEND = 0x0004, /* size increased */
    NOTE_ATTRIB = 0x0008, /* attributes changed */
    NOTE_LINK = 0x0010, /* link count changed */
    NOTE_RENAME = 0x0020, /* vnode was renamed */
    NOTE_REVOKE = 0x0040, /* vnode access was revoked */

    /*
        * data/hint flags for EVFILT_PROC, shared with userspace
        */
    NOTE_EXIT = 0x80000000, /* process exited */
    NOTE_FORK = 0x40000000, /* process forked */
    NOTE_EXEC = 0x20000000, /* process exec'd */
    NOTE_PCTRLMASK = 0xf0000000, /* mask for hint bits */
    NOTE_PDATAMASK = 0x000fffff, /* mask for pid */

    /* additional flags for EVFILT_PROC */
    NOTE_TRACK = 0x00000001, /* follow across forks */
    NOTE_TRACKERR = 0x00000002, /* could not track child */
    NOTE_CHILD = 0x00000004, /* am a child process */

}

int kqueue();
int kevent(int kq, const kevent_t* changelist, int nchanges, kevent_t* eventlist,
    int nevents, const timespec* timeout);
    }
