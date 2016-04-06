module collie.channel.selector.kqueue;

version (FreeBSD) 
{
	version = KQUEUE;
}
else version (OpenBSD) 
{
	version = KQUEUE;
}
else version (NetBSD)
{
	version = KQUEUE;
}
else version (OSX) 
{
	version = KQUEUE;
}
//version = KQUEUE;
version(KQUEUE):

import core.memory;

//TODO: 定时器有问题，
public import core.sys.posix.sys.types; // for ssize_t, size_t
public import core.sys.posix.netinet.tcp;
public import core.sys.posix.netinet.in_;
public import core.stdc.stdint;    // intptr_t, uintptr_t
public import core.sys.posix.time; // timespec
public import core.sys.posix.config;

import std.exception;
import std.container : Array;
import std.stdio;

import collie.channel.define;
import collie.channel.channel;
import collie.channel.timer;


enum EVENT_KQUEUE_SIZE = 128;

class KqueueLoop
{
	/** 构造函数，构建一个epoll事件
	 */
	this ()
	{
		if ((_efd = kqueue()) < 0)
		{
			errnoEnforce("kqueue failed");
		}
		events =  colliedAllocator.makeArray!kevent_t(EVENT_KQUEUE_SIZE);
	}
	
	/** 析构函数，释放epoll。
	 */
	~this ()
	{
		.close(_efd);
		colliedAllocator.deallocate(events);
	}
	
	/** 开始执行事件等待。
	 @param :timeout = 无事件的超时等待时间。单位：毫秒
	 @note : 此函数可以多线程同时执行，实现多个线程共用一个事件调度。

	 */
	void wait(int timeout)
	{
		auto tm = timeout % 1000;
		auto tspec = timespec(timeout / 1000 , tm * 1000 * 1000);
		auto num = kevent(_efd, null, 0, cast(kevent_t*) events, cast(int) events.length, &tspec);
		for(ulong i = 0; i < num; ++i){
			auto channel = cast(Channel)events[i].udata;
			//int event_flags = (_event.filter << 16) | (_event.flags & 0xffff);
			if(channel.type == CHANNEL_TYPE.Timer){
				writeln("timer !!!");
			}
			if((events[i].flags & EV_EOF) || (events[i].flags &EV_ERROR)){
				channel.onClose();
			}
			if(channel.type == CHANNEL_TYPE.Timer){
				channel.onRead();
				writeln("timer !!! channel.onRead();");
				continue;
			}

			if(events[i].filter & EVFILT_READ) {
				channel.onRead();
			}

			if(events[i].filter & EVFILT_WRITE ){
				channel.onWrite();
			}
		}
	}

	/**
	 * 添加TcpSocket对象
	 */
	bool addEvent (Channel socket){
		if (socket.isInValid()) {
			return false;
		}

		auto ptr = cast(void *)socket;
		int err = 0;
		GC.setAttr(ptr,GC.BlkAttr.NO_MOVE);
		switch (socket.type) {
			case CHANNEL_TYPE.TCP_Listener:
			case CHANNEL_TYPE.SSL_Listener:
			{
				kevent_t event;
				EV_SET(&event, socket.fd, EVFILT_READ, EV_ADD | EV_ENABLE, 0, 0, ptr);
				err = kevent(_efd, &event, 1, null, 0, null);
			}
				break;
			case CHANNEL_TYPE.Timer:
			{
				kevent_t event;
				auto timer = cast(Timer)socket;
				long msec;
				timer.TimeOut.split!"msecs" (msec);
				msec += 10;
				writeln("start timer : time  = ",msec);
				EV_SET(&event, timer.fd, EVFILT_TIMER, EV_ADD | EV_ENABLE | EV_CLEAR, 0, msec, ptr);//单位毫秒
				err = kevent(_efd, &event, 1, null, 0, null);
			}
				break;
			case CHANNEL_TYPE.Event :
				return false;
			case CHANNEL_TYPE.TCP_Socket :
			case CHANNEL_TYPE.SSL_Socket:
			{
				kevent_t[2] event = void;
				EV_SET(&(event[0]), socket.fd, EVFILT_READ, EV_ADD | EV_ENABLE | EV_CLEAR, 0, 0, ptr);
				EV_SET(&(event[1]), socket.fd, EVFILT_WRITE, EV_ADD | EV_ENABLE | EV_CLEAR, 0, 0, ptr);
				err = kevent(_efd, &(event[0]), 2, null, 0, null);
			}
				break;
			default :
				return false;
		}
		if(err < 0){
			GC.clrAttr(ptr,GC.BlkAttr.NO_MOVE);
			return false;
		}

		return true;
	}

	// called on run
	nothrow int createIndex() {
		size_t idx;
		import std.algorithm : max;
		try {
			
			size_t getIdx() {
				
				if (!g_evIdxAvailable.empty) {
					immutable size_t ret = g_evIdxAvailable.back;
					g_evIdxAvailable.removeBack();
					return ret;
				}
				return 0;
			}
			
			idx = getIdx();
			if (idx == 0) {
				import std.range : iota;
				g_evIdxAvailable.insert( iota(g_evIdxCapacity, max(32, g_evIdxCapacity * 2), 1) );
				g_evIdxCapacity = max(32, g_evIdxCapacity * 2);
				idx = getIdx();
			}
			
		} catch (Throwable e) {
			version(DEBUG) {
				import std.stdio : writeln;
				try writeln(e.toString()); catch {}
			}

		}
		return cast(int)idx;
	}
	
	nothrow void destroyIndex(int idx) {
		try {
			g_evIdxAvailable.insert(cast(size_t)idx);
		}
		catch (Exception e) {
			assert(false, "Error destroying index: " ~ e.msg);
		}
	}


	bool removeTimer(Timer tm){
		auto ptr = cast(void *)tm;
		kevent_t event;
		 EV_SET(&event, tm.fd, EVFILT_TIMER, EV_DELETE, 0, 0, ptr);//单位毫秒
		 int err = kevent(_efd, &event, 1, null, 0, null);
		if(err < 0) return false;
		return true;
	}

	/**
	 * del TcpSocket对象
	 */
	
	bool delEvent(Channel socket){
		if (!socket.isInValid()) {
			//	int tfd = socket.fd;
			auto ptr = cast(void *)socket;
			int err = 0;
			switch (socket.type) {
				case CHANNEL_TYPE.TCP_Listener:
				case CHANNEL_TYPE.SSL_Listener:
				{
					kevent_t event;
					EV_SET(&event, socket.fd, EVFILT_READ, EV_DELETE, 0, 0, ptr);
					err = kevent(_efd, &event, 1, null, 0, null);
				}
					break;
				case CHANNEL_TYPE.Timer:
				{
					kevent_t event;
					/*auto timer = cast(Timer)socket;
					long msec;
					timer.TimeOut.split!"msecs" (msec);
					msec += 10;*/
					EV_SET(&event, socket.fd, EVFILT_TIMER, EV_DELETE, 0, 0, ptr);//单位毫秒
					err = kevent(_efd, &event, 1, null, 0, null);
					destroyIndex(socket.fd);
				}
					break;
				case CHANNEL_TYPE.Event :
					return false;
				case CHANNEL_TYPE.TCP_Socket :
				case CHANNEL_TYPE.SSL_Socket:
				{
					kevent_t[2] event = void;
					EV_SET(&(event[0]), socket.fd, EVFILT_READ, EV_DELETE, 0, 0, ptr);
					EV_SET(&(event[1]), socket.fd, EVFILT_WRITE, EV_DELETE, 0, 0, ptr);
					err = kevent(_efd, &(event[0]), 2, null, 0, null);
				}
					break;
				default :
					return false;
			}
			if(err < 0){
				import std.stdio;
				writeln("kqueue ev_delete erro ! fd = ",socket.fd);
			}
			close(socket.fd);
			GC.clrAttr(cast(void *)socket,GC.BlkAttr.NO_MOVE);
			socket.fd  = -1;
			return true;
		}
		return false;
	}
	
	
	void weakUp(){}
private:
	/** 存储 epoll的fd */
	int           _efd;
	kevent_t[] events;
	size_t g_evIdxCapacity;
	Array!size_t g_evIdxAvailable;
}



extern (C):
@nogc:
struct timespec
{
	time_t  tv_sec;
	c_long  tv_nsec;
}

enum : short
{
	EVFILT_READ     =  -1,
	EVFILT_WRITE    =  -2,
	EVFILT_AIO      =  -3, /* attached to aio requests */
	EVFILT_VNODE    =  -4, /* attached to vnodes */
	EVFILT_PROC     =  -5, /* attached to struct proc */
	EVFILT_SIGNAL   =  -6, /* attached to struct proc */
	EVFILT_TIMER    =  -7, /* timers */
	EVFILT_MACHPORT =  -8, /* Mach portsets */
	EVFILT_FS       =  -9, /* filesystem events */
	EVFILT_USER     = -10, /* User events */
	EVFILT_VM		= -12, /* virtual memory events */
	EVFILT_SYSCOUNT =  11
}

extern(D) void EV_SET(kevent_t* kevp, typeof(kevent_t.tupleof) args)
{
	*kevp = kevent_t(args);
}

struct kevent_t
{
	uintptr_t    ident; /* identifier for this event */
	short       filter; /* filter for event */
	ushort       flags;
	uint        fflags;
	intptr_t      data;
	void        *udata; /* opaque user data identifier */
}

enum
{
	/* actions */
	EV_ADD      = 0x0001, /* add event to kq (implies enable) */
	EV_DELETE   = 0x0002, /* delete event from kq */
	EV_ENABLE   = 0x0004, /* enable event */
	EV_DISABLE  = 0x0008, /* disable event (not reported) */
	
	/* flags */
	EV_ONESHOT  = 0x0010, /* only report one occurrence */
	EV_CLEAR    = 0x0020, /* clear event state after reporting */
	EV_RECEIPT  = 0x0040, /* force EV_ERROR on success, data=0 */
	EV_DISPATCH = 0x0080, /* disable event after reporting */
	
	EV_SYSFLAGS = 0xF000, /* reserved by system */
	EV_FLAG1    = 0x2000, /* filter-specific flag */
	
	/* returned values */
	EV_EOF      = 0x8000, /* EOF detected */
	EV_ERROR    = 0x4000, /* error, data contains errno */
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
	NOTE_FFNOP      = 0x00000000, /* ignore input fflags */
	NOTE_FFAND      = 0x40000000, /* AND fflags */
	NOTE_FFOR       = 0x80000000, /* OR fflags */
	NOTE_FFCOPY     = 0xc0000000, /* copy fflags */
	NOTE_FFCTRLMASK = 0xc0000000, /* masks for operations */
	NOTE_FFLAGSMASK = 0x00ffffff,
	
	NOTE_TRIGGER    = 0x01000000, /* Cause the event to be
                                  triggered for output. */
	
	/*
     * data/hint flags for EVFILT_{READ|WRITE}, shared with userspace
     */
	NOTE_LOWAT      = 0x0001, /* low water mark */
	
	/*
     * data/hint flags for EVFILT_VNODE, shared with userspace
     */
	NOTE_DELETE     = 0x0001, /* vnode was removed */
	NOTE_WRITE      = 0x0002, /* data contents changed */
	NOTE_EXTEND     = 0x0004, /* size increased */
	NOTE_ATTRIB     = 0x0008, /* attributes changed */
	NOTE_LINK       = 0x0010, /* link count changed */
	NOTE_RENAME     = 0x0020, /* vnode was renamed */
	NOTE_REVOKE     = 0x0040, /* vnode access was revoked */
	
	/*
     * data/hint flags for EVFILT_PROC, shared with userspace
     */
	NOTE_EXIT       = 0x80000000, /* process exited */
	NOTE_FORK       = 0x40000000, /* process forked */
	NOTE_EXEC       = 0x20000000, /* process exec'd */
	NOTE_PCTRLMASK  = 0xf0000000, /* mask for hint bits */
	NOTE_PDATAMASK  = 0x000fffff, /* mask for pid */
	
	/* additional flags for EVFILT_PROC */
	NOTE_TRACK      = 0x00000001, /* follow across forks */
	NOTE_TRACKERR   = 0x00000002, /* could not track child */
	NOTE_CHILD      = 0x00000004, /* am a child process */
}

int kqueue();
int kevent(int kq, const kevent_t *changelist, int nchanges,
	kevent_t *eventlist, int nevents,
	const timespec *timeout);

