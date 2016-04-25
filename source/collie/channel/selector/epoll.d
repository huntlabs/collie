/* Copyright collied.org 
 */

module collie.channel.selector.epoll;

version (linux) :

import core.time;
import core.stdc.errno;
import core.memory;

public import core.sys.posix.sys.types; // for ssize_t, size_t
public import core.sys.posix.netinet.tcp;
public import core.sys.posix.netinet.in_;
import core.sys.posix.time : itimerspec, CLOCK_MONOTONIC;
import core.sys.posix.unistd;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.format;

import collie.channel.define;
import collie.channel.channel;

enum EVENT_POLL_SIZE = 1;

/** 系统I/O事件处理类，epoll操作的封装
 @authors  Putao‘s Collie Team
 @date      2016.1
 */
final class EpollLoop {
	/** 构造函数，构建一个epoll事件
	 */
	this () {
		if ((_efd = epoll_create1(0)) < 0) {
			errnoEnforce("epoll_create1 failed");
		}
		events =  colliedAllocator.makeArray!epoll_event(EVENT_POLL_SIZE);
		_event = new EventChannel();
		addEvent(_event);
	}

	/** 析构函数，释放epoll。
	 */
	~this () {
		delEvent(_event);
		.close(_efd);
		_event = null;
		colliedAllocator.deallocate(events);
	}

	/** 添加一个Channel对象到事件队列中。
	 @param   socket = 添加到时间队列中的Channel对象，根据其type自动选择需要注册的事件。
	 @return true 添加成功, false 添加失败，并把错误记录到日志中.
	 */
	bool addEvent (Channel socket) {
		if (socket.isInValid()) {
			return false;
		}
		epoll_event  ev;
		ev.data.ptr = cast(void *)socket;//socket.channelptr;
		GC.setAttr(ev.data.ptr,GC.BlkAttr.NO_MOVE);
		switch (socket.type) {
			case CHANNEL_TYPE.TCP_Listener:
			case CHANNEL_TYPE.SSL_Listener:
				ev.events = 0 | EPOLLIN | EPOLLET;
				break;
			case CHANNEL_TYPE.Timer:
			case CHANNEL_TYPE.Event :
				ev.events = 0 | EPOLLIN | EPOLLET;
				break;
			case CHANNEL_TYPE.TCP_Socket :
			case CHANNEL_TYPE.SSL_Socket:
				ev.events = 0 | EPOLLHUP | EPOLLERR | EPOLLIN |  EPOLLOUT  | EPOLLRDHUP | EPOLLET;//0 | EPOLLIN | EPOLLOUT | EPOLLERR | EPOLLHUP | EPOLLRDHUP | EPOLLET;
				break;
			default :
				return false;
		}

		try {
			if ((epoll_ctl(_efd, EPOLL_CTL_ADD, socket.fd, &ev)) != 0) {
				error("EPOLL_CTL_ADD fd :",socket.fd," failed with :",errno);
				GC.clrAttr(ev.data.ptr,GC.BlkAttr.NO_MOVE);
				return false;
			}
		} catch (ErrnoException e) {
			if (e.errno != EEXIST)
			{
				throw e;
			}
		}

		return true;
	}

	
	/** 从epoll队列中移除Channel对象。
	 @param socket = 需要移除的Channel对象
	 @return (true) 移除成功, (false) 移除失败，并把错误输出到控制台.
	 */
	bool delEvent (Channel socket) {
		try {
			if (!socket.isInValid()) {
				//	int tfd = socket.fd;
				epoll_event  ev;
				if ((epoll_ctl(_efd, EPOLL_CTL_DEL, socket.fd, &ev)) != 0) {
					error("EPOLL_CTL_DEL erro! " ,socket.fd);
					return false;
				}

				close(socket.fd);
				GC.clrAttr(cast(void *)socket,GC.BlkAttr.NO_MOVE);
				socket.fd  = -1;
			}
			
		} catch (ErrnoException e) {
			if (e.errno != ENOENT) 
			{
				throw e;
			}
		}

		return true;
	}

	/** 调用epoll_wait。
	 *    @param    timeout = epoll_wait的等待时间
	 *    @param    eptr   = epoll返回时间的存储的数组指针
	 *    @param    size   = 数组的大小
	 *    @return 返回当前获取的事件的数量。
	 */

	void wait(int timeout) {
		try {
			int length = epoll_wait(_efd, events.ptr, EVENT_POLL_SIZE, timeout);
			for (int i = 0; i < length; ++i) {
				auto channelHandler = cast(Channel)(events[i].data.ptr);
				assert(channelHandler);                
				if (events[i].events & (EPOLLHUP | EPOLLERR | EPOLLRDHUP)) {
					channelHandler.onClose();
					return;
				}
				
				if (events[i].events & EPOLLIN) {
					channelHandler.onRead();
				}
				
				if (events[i].events & EPOLLOUT) { //ET模式下，同时监听，每次epollin事件的时候总会带着epollout事件，这也是单线程监听一次监听多个有时不如每次注册的原因
					channelHandler.onWrite();
				}
			}

		} catch (ErrnoException e) {
			if (e.errno != EINTR && e.errno != EAGAIN && e.errno != 4) {
				throw e;
			}
		}
		return;
	}

	void weakUp() {
		_event.write();
	}

private:
	/** 存储 epoll的fd */
	int _efd;
	epoll_event[] events;
	EventChannel _event;
}

static this() {
	import core.sys.posix.signal;
	signal(SIGPIPE, SIG_IGN);
}

class EventChannel : Channel {
	this() {
		super(null);
		type = CHANNEL_TYPE.Event;
		fd = eventfd(0, EFD_NONBLOCK | EFD_CLOEXEC);
	}

	~this() {
		if(!isInValid())
			close(fd);
	}
	
	void write() {
		ulong ul = 1;
		core.sys.posix.unistd.write(fd,&ul,ul.sizeof);
	}

	override void onRead() {
		ulong ul = 1;
		size_t len = read(fd,&ul,ul.sizeof);
	}

	override void onWrite(){}
	override void onClose(){}
};

extern (C):
@system:
nothrow:

extern(C) enum
{
	EFD_SEMAPHORE = 0x1,
	EFD_CLOEXEC = 0x80000,
	EFD_NONBLOCK = 0x800
};

enum
{
	EPOLL_CLOEXEC  = 0x80000,
	EPOLL_NONBLOCK = 0x800
}

enum
{
	EPOLLIN     = 0x001,
	EPOLLPRI    = 0x002,
	EPOLLOUT    = 0x004,
	EPOLLRDNORM = 0x040,
	EPOLLRDBAND = 0x080,
	EPOLLWRNORM = 0x100,
	EPOLLWRBAND = 0x200,
	EPOLLMSG    = 0x400,
	EPOLLERR    = 0x008,
	EPOLLHUP    = 0x010,
	EPOLLRDHUP  = 0x2000, // since Linux 2.6.17
	EPOLLONESHOT = 1u << 30,
	EPOLLET     = 1u << 31
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
align(1):
	uint events;
	epoll_data_t data;
}

union epoll_data_t
{
	void *ptr;
	int fd;
	uint u32;
	ulong u64;
}

int epoll_create (int size);
int epoll_create1 (int flags);
int epoll_ctl (int epfd, int op, int fd, epoll_event *event);
int epoll_wait (int epfd, epoll_event *events, int maxevents, int timeout);


int eventfd (uint initval, int flags);

//timerfd


int timerfd_create(int clockid, int flags);
int timerfd_settime(int fd, int flags, const itimerspec* new_value, itimerspec* old_value);
int timerfd_gettime(int fd, itimerspec* curr_value);

enum TFD_TIMER_ABSTIME = 1 << 0;
enum TFD_CLOEXEC       = 0x80000;
enum TFD_NONBLOCK      = 0x800;
