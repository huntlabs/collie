/* Copyright collied.org 
 */

module collie.socket.selector.epoll;

version (linux)  : import core.time;
import core.stdc.errno;
import core.memory;

import core.sys.posix.sys.types; // for ssize_t, size_t
import core.sys.posix.netinet.tcp;
import core.sys.posix.netinet.in_;
import core.sys.posix.time : itimerspec, CLOCK_MONOTONIC;
import core.sys.posix.unistd;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.format;
import std.socket;
import std.experimental.logger;

import collie.socket.common;

enum EVENT_POLL_SIZE = 128;

/** 系统I/O事件处理类，epoll操作的封装
 @authors  Putao‘s Collie Team
 @date      2016.1
 */
final class EpollLoop
{
    /** 构造函数，构建一个epoll事件
	 */
    this()
    {
        if ((_efd = epoll_create1(0)) < 0)
        {
            errnoEnforce("epoll_create1 failed");
        }
        _events = new epoll_event[EVENT_POLL_SIZE];
        _event = new EventChannel();
        addEvent(_event._event);
    }

    /** 析构函数，释放epoll。
	 */
    ~this()
    {
        delEvent(_event._event);
        .close(_efd);
        //delete _events;
        _event = null;
    }

    /** 添加一个Channel对象到事件队列中。
	 @param   socket = 添加到时间队列中的Channel对象，根据其type自动选择需要注册的事件。
	 @return true 添加成功, false 添加失败，并把错误记录到日志中.
	 */
    bool addEvent(AsyncEvent * event) nothrow
    {
        if (event.fd == socket_t.init)
            return false;

        mixin(mixinModEvent());

        if ((epoll_ctl(_efd, EPOLL_CTL_ADD, event.fd,  & ev)) != 0)
        {
            if (errno != EEXIST)
                return false;
        }
        event.isActive = true;
        return true;
    }

    bool modEvent(AsyncEvent * event) nothrow
    {
        if (event.fd == socket_t.init)
            return false;
        mixin(mixinModEvent());

        if ((epoll_ctl(_efd, EPOLL_CTL_MOD, event.fd,  & ev)) != 0)
        {
            return false;
        }
        event.isActive = true;
        return true;
    }

    /** 从epoll队列中移除Channel对象。
	 @param socket = 需要移除的Channel对象
	 @return (true) 移除成功, (false) 移除失败，并把错误输出到控制台.
	 */
    bool delEvent(AsyncEvent * event) nothrow
    {
        if (event.fd == socket_t.init)
            return false;
        epoll_event ev;
        if ((epoll_ctl(_efd, EPOLL_CTL_DEL, event.fd,  & ev)) != 0)
        {
            try
            {
                error("EPOLL_CTL_DEL erro! ", event.fd);
            }
            catch
            {
            }
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
        try
        {
            int length = epoll_wait(_efd, _events.ptr, EVENT_POLL_SIZE, timeout);
            EventCallInterface[EVENT_POLL_SIZE] objs;
            foreach(i;0..length)
            {
                objs[i] = (cast(AsyncEvent * )(_events[i].data.ptr)).obj;
                assert(objs[i]);
            }
            for (int i = 0; i < length; ++i)
            {
                if (isErro(_events[i].events))
                {
                    objs[i].onClose();
                    return;
                }

                if (isWrite(_events[i].events))
                   objs[i].onWrite();

                if (isRead(_events[i].events))
                    objs[i].onRead();
            }

        }
        catch (ErrnoException e)
        {
            if (e.errno != EINTR && e.errno != EAGAIN && e.errno != 4)
            {
                throw e;
            }
        }
        return;
    }

    void weakUp() nothrow
    {
        _event.doWrite();
    }


protected : 
    pragma(inline, true);
    bool isErro(uint events)
    {
        return (events & (EPOLLHUP | EPOLLERR | EPOLLRDHUP)) != 0;
    }
    pragma(inline, true);
    bool isRead(uint events)
    {
        return (events & EPOLLIN) != 0;
    }
    pragma(inline, true);
    bool isWrite(uint events)
    {
        return (events & EPOLLOUT) != 0;
    }

private : /** 存储 epoll的fd */
    int _efd;
    epoll_event[] _events;
    EventChannel _event;
}

static this()
{
    import core.sys.posix.signal;

    signal(SIGPIPE, SIG_IGN);
}

enum EPOLL_EVENT : short
{
    init =  - 5
};

final class EventChannel : EventCallInterface
{
    this()
    {
        _fd = cast(socket_t) eventfd(0, EFD_NONBLOCK | EFD_CLOEXEC);
        _event = new AsyncEvent(AsynType.EVENT, this, _fd, true, false, false);
        GC.setAttr(_event, GC.BlkAttr.NO_MOVE);

    }
    ~this()
    {
        .close(_fd);
        delete _event;
    }

    void doWrite() nothrow
    {
        ulong ul = 1;
        core.sys.posix.unistd.write(_fd,  & ul, ul.sizeof);
    }
    override void onRead() nothrow
    {
        ulong ul = 1;
        size_t len = read(_fd,  & ul, ul.sizeof);
    }

    override void onWrite() nothrow
    {
    }

    override void onClose() nothrow
    {
    }

    socket_t _fd;
    AsyncEvent * _event;
};

string mixinModEvent()
{
    string str = "epoll_event ev; \n ev.data.ptr = event; \n ev.events = EPOLLRDHUP | EPOLLERR | EPOLLHUP; \n if(event.enRead) ev.events |= EPOLLIN; \n ";
    str ~= "if(event.enWrite) ev.events |= EPOLLOUT;\n if(event.oneShot) ev.events |= EPOLLONESHOT; \n if(event.etMode) ev.events |= EPOLLET; ";
    return str;
}

extern (C) : 
@system : 
nothrow : 
enum
{
    EFD_SEMAPHORE = 0x1,
    EFD_CLOEXEC = 0x80000,
    EFD_NONBLOCK = 0x800
};

enum
{
    EPOLL_CLOEXEC = 0x80000,
    EPOLL_NONBLOCK = 0x800
}

enum
{
    EPOLLIN = 0x001,
    EPOLLPRI = 0x002,
    EPOLLOUT = 0x004,
    EPOLLRDNORM = 0x040,
    EPOLLRDBAND = 0x080,
    EPOLLWRNORM = 0x100,
    EPOLLWRBAND = 0x200,
    EPOLLMSG = 0x400,
    EPOLLERR = 0x008,
    EPOLLHUP = 0x010,
    EPOLLRDHUP = 0x2000, // since Linux 2.6.17
    EPOLLONESHOT = 1u << 30,
    EPOLLET = 1u << 31
}

/* Valid opcodes ( "op" parameter ) to issue to epoll_ctl().  */
enum
{
    EPOLL_CTL_ADD = 1, // Add a file descriptor to the interface.
    EPOLL_CTL_DEL = 2, // Remove a file descriptor from the interface.
    EPOLL_CTL_MOD = 3, // Change file descriptor epoll_event structure.
}

align(1) struct epoll_event
{
    align(1) : uint events;
    epoll_data_t data;
}

union epoll_data_t
{
    void * ptr;
    int fd;
    uint u32;
    ulong u64;
}

int epoll_create(int size);
int epoll_create1(int flags);
int epoll_ctl(int epfd, int op, int fd, epoll_event * event);
int epoll_wait(int epfd, epoll_event * events, int maxevents, int timeout);

int eventfd(uint initval, int flags);

//timerfd

int timerfd_create(int clockid, int flags);
int timerfd_settime(int fd, int flags, const itimerspec * new_value, itimerspec * old_value);
int timerfd_gettime(int fd, itimerspec * curr_value);

enum TFD_TIMER_ABSTIME = 1 << 0;
enum TFD_CLOEXEC = 0x80000;
enum TFD_NONBLOCK = 0x800;
