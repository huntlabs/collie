/* Copyright collied.org 
 */

module collie.channel.channel;

import core.atomic;
import core.memory;

import collie.channel;
import collie.channel.pipeline;
public import collie.channel.eventloop;

/** 传送给事件循环可监视的I/O对象的基类
 @authors : Putao‘s Collie Team
 @date : 2016.1
 */
class Channel {
public:
	/** 构造函数，指定此对象所属的事件循环
	 *    @param : loop = 所属的事件循环
	 */
	this(EventLoop loop) {
		eventLoop = loop;
	}

	~this() {
		if(_pipeline)
			_pipeline.destroy;
		_pipeline = null;
	}

	/** 获取当前Channel所属的事件的循环 */
	final @safe @property EventLoop eventLoop() { return _loop; }
	/** 当此对象有可读事件时调用的方法。 */
	abstract void onRead();

	/** 当此对象有可写事件时调用的方法。 */
	abstract void onWrite();

	/** 当此对象有可写事件时调用的方法。 */
	abstract void onClose();
	/** 获取当前channel的fd */
	final @property int fd() const {return _fd;}//atomicLoad(_fd);}
	/** fd是否失效 
	 *   @return true:无效，false 有效
	 */
	final  bool isInValid() const { return ( fd <= 0); }

	final @safe  @property PiPeline pipeline() { return _pipeline; }

	/** 获取当前Channel的类型 */
	@property CHANNEL_TYPE type() const {
		return _type;
	}

protected:
	/** 设置所属的事件循环 */
	final @safe @property void eventLoop(EventLoop loop) { _loop = loop; }
package :
	/** 设置fd */
	@property void fd(int tfd) { _fd = tfd; }//{atomicStore(_fd,tfd);}
	/** 设置当前Channel的类型 */
	@property void type(CHANNEL_TYPE sType) {
		_type = sType;
	}
	
	/** 当前所属的事件循环 */
	EventLoop  _loop = null;
	/** 当前的fd信息， */
	/*shared */int  _fd = -1;

private:
	/** Channel的类型 */
	CHANNEL_TYPE _type; // socket's type
	PiPeline _pipeline = null;
};


static if(IOMode == IO_MODE.epoll){
	version (X86) {
		enum SO_REUSEPORT	= 15;
	} else version (X86_64) {
		enum SO_REUSEPORT	= 15;
	} else version (MIPS32) {
		enum SO_REUSEPORT	= 0x0200;
	} else version (MIPS64) {
		enum SO_REUSEPORT	= 0x0200;
	} else version (PPC) {
		enum SO_REUSEPORT	= 15;
	} else version (PPC64) {
		enum SO_REUSEPORT	= 15;
	} else version (ARM) {
		enum SO_REUSEPORT	= 15;
	}
} else static if(IOMode == IO_MODE.kqueue) {
	enum SO_REUSEPORT	= 0x0200;
}

enum TCPOption : char {
	NODELAY = 0,		// Don't delay send to coalesce packets
	REUSEADDR = 1,
	REUSEPORT,
	CORK,
	LINGER,
	BUFFER_RECV,
	BUFFER_SEND,
	TIMEOUT_RECV,
	TIMEOUT_SEND,
	TIMEOUT_HALFOPEN,
	KEEPALIVE_ENABLE,
	KEEPALIVE_DEFER,	// Start keeplives after this period
	KEEPALIVE_COUNT,	// Number of keepalives before death
	KEEPALIVE_INTERVAL,	// Interval between keepalives
	DEFER_ACCEPT,
	CONGESTION
};

/** 设置Tcp相关参数的混入模板 */
mixin template SocketOption() {
public:
	/** 返回当前fd是否是异步的。 */
	@property asynchronous() {
		version (Posix) {
			return (fcntl(fd, F_GETFL, 0) & O_NONBLOCK) != 0;
		}
	}
	
	/** 设置当前TCP fd 的属性 
	 @return : true 设置成功，false 设置失败
	 */
	bool setOption(T)(TCPOption option, in T value) {
		import std.traits : isIntegral;
		int err;
		nothrow bool errorHandler() {
			if (err == -1) { 
				try {
					error("setOption Erro the  value :",to!string(err),"  the option is ",to!string(option));
				} catch {}
				return false;
			} else {
				return true;
			}
		}
		final switch (option) {
			case TCPOption.NODELAY: // true/false
				static if(!is(T == bool)) {
					assert(false, "NODELAY value type must be bool, not " ~ T.stringof);
				} else {
					int val = value?1:0;
					uint len = val.sizeof;
					err = setsockopt(fd, IPPROTO_TCP, core.sys.posix.netinet.tcp.TCP_NODELAY, &val, len);
					return errorHandler();
				}
				
			case TCPOption.REUSEADDR: // true/false
			case TCPOption.REUSEPORT:
				static if(!is(T == bool)) {
					assert(false, "REUSEADDR value type must be bool, not " ~ T.stringof);
				} else {
					int val = value?1:0;
					uint len = val.sizeof;
					err = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &val, len);
					if(!errorHandler())
						return false;
					// BSD systems have SO_REUSEPORT
					err = setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &val, len);
					
					// Not all linux kernels support SO_REUSEPORT
					version(linux) {
						// ignore invalid and not supported errors on linux
						if(errno == EINVAL || errno == ENOPROTOOPT) {
							try {
								trace("set SO_REUSEPORT not  supported over the value = ",to!string(err), " the erro = ", to!string(errno));
							} catch {}
							return true;
						}
					}

					return errorHandler();
				}
			case TCPOption.KEEPALIVE_ENABLE: // true/false
				static if(!is(T == bool)) {
					assert(false, "KEEPALIVE_ENABLE value type must be bool, not " ~ T.stringof);
				} else {
					int val = value ? 1 : 0;
					uint len = val.sizeof;
					err = setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, &val, len);
					return errorHandler();
				}
			case TCPOption.KEEPALIVE_COUNT: // ## 重试次数
				static if(!isIntegral!T) {
					assert(false, "KEEPALIVE_COUNT value type must be integral, not " ~ T.stringof);
				} else {
					int val = value;//value.total!"msecs".to!uint;
					uint len = val.sizeof;
					err = setsockopt(fd, IPPROTO_TCP, TCP_KEEPCNT, &val, len);
					return errorHandler();
				}
			case TCPOption.KEEPALIVE_INTERVAL: // wait ## seconds，第二次重试间隔
				static if(!is(T == Duration)) {
					assert(false, "KEEPALIVE_INTERVAL value type must be Duration, not " ~ T.stringof);
				} else {
					int val;
					try {
						val = value.total!"seconds".to!uint;
					} catch {
						return false;
					}
					uint len = val.sizeof;
					err = setsockopt(fd, IPPROTO_TCP, TCP_KEEPINTVL, &val, len);
					return errorHandler();
				}
			case TCPOption.KEEPALIVE_DEFER: // wait ## seconds until start,设置空闲时长
				static if(!is(T == Duration)) {
					assert(false, "KEEPALIVE_DEFER value type must be Duration, not " ~ T.stringof);
				} else {
					int val;
					try val = value.total!"seconds".to!uint; catch { return false; }
					uint len = val.sizeof;
					err = setsockopt(fd, IPPROTO_TCP, TCP_KEEPIDLE, &val, len);
					return errorHandler();
				}
			case TCPOption.BUFFER_RECV: // bytes
				static if (!isIntegral!T) {
					assert(false, "BUFFER_RECV value type must be integral, not " ~ T.stringof);
				} else {
					int val = value.to!int;
					uint len = val.sizeof;
					err = setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &val, len);
					return errorHandler();
				}
			case TCPOption.BUFFER_SEND: // bytes
				static if(!isIntegral!T) {
					assert(false, "BUFFER_SEND value type must be integral, not " ~ T.stringof);
				} else {
					int val = value.to!int;
					uint len = val.sizeof;
					err = setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &val, len);
					return errorHandler();
				}
			case TCPOption.TIMEOUT_RECV:
				static if(!is(T == Duration)) {
					assert(false, "TIMEOUT_RECV value type must be Duration, not " ~ T.stringof);
				} else {
					import core.sys.posix.sys.time : timeval;
					time_t secs = cast(time_t) value.split!("seconds", "usecs")().seconds;
					suseconds_t us;
					try us = value.split!("seconds", "usecs")().usecs.to!suseconds_t; catch {}
					timeval t = timeval(secs, us);
					uint len = t.sizeof;
					err = setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &t, len);
					return errorHandler();
				}
			case TCPOption.TIMEOUT_SEND:
				static if(!is(T == Duration)) {
					assert(false, "TIMEOUT_SEND value type must be Duration, not " ~ T.stringof);
				} else {
					import core.sys.posix.sys.time : timeval;
					auto timeout = value.split!("seconds", "usecs")();
					timeval t;
					try t = timeval(timeout.seconds.to!time_t, timeout.usecs.to!suseconds_t);
					catch (Exception) { return false; }
					uint len = t.sizeof;
					err = setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &t, len);
					return errorHandler();
				}
			case TCPOption.TIMEOUT_HALFOPEN:
				static if(!is(T == Duration)) {
					assert(false, "TIMEOUT_SEND value type must be Duration, not " ~ T.stringof);
				} else {
					uint val;
					try {
						val = value.total!"msecs".to!uint;
					} catch {
						return false;
					}
					uint len = val.sizeof;
					err = setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &val, len);
					return errorHandler();
				}
			case TCPOption.LINGER: // bool onOff, int seconds
				static if(!is(T == linger)) {
					assert(false, "LINGER value type must be linger, not " ~ T.stringof);
				} else {
					linger l = linger(value[0] ? 1 : 0, value[1]);
					uint llen = T.sizeof;
					err = setsockopt(fd, SOL_SOCKET, SO_LINGER, &T, llen);
					return errorHandler();
				}
			case TCPOption.CONGESTION:
				static if(!isIntegral!T) {
					assert(false, "CONGESTION value type must be integral, not " ~ T.stringof);
				} else {
					int val = value.to!int;
					uint len = int.sizeof;
					err = setsockopt(fd, IPPROTO_TCP, TCP_CONGESTION, &val, len);
					return errorHandler();
				}
			case TCPOption.CORK:
				static if(!isIntegral!T) {
					assert(false, "CORK value type must be int, not " ~ T.stringof);
				} else {
					int val = value.to!int;
					uint len = val.sizeof;
					err = setsockopt(fd, IPPROTO_TCP, TCP_CORK, &val, len);
					return errorHandler();

				}
			case TCPOption.DEFER_ACCEPT: // seconds
				static if(!isIntegral!T) {
					assert(false, "DEFER_ACCEPT value type must be integral, not " ~ T.stringof);
				} else {
					int val = value.to!int;
					uint len = val.sizeof;
					err = setsockopt(fd, IPPROTO_TCP, TCP_DEFER_ACCEPT, &val, len);
					return errorHandler();
				}
		}

	}
	
	/** 设置当前ChannelTCP的链接地址 */
	@property address(Address address) {
		_address = address;
	}

	/** 获取当前ChannelTCP的链接地址 */
	@property address(){
		return _address;
	}

	bool getOption(T)(TCPOption option, out T value) { //TODO: 完善获取配置的值
		import std.traits : isIntegral;
		int err;
		nothrow bool errorHandler() {
			if(catchError!"getsockopt:"(err)) {
				return false;
			}
			return true;
		}

		final switch (option) {
			case TCPOption.NODELAY: // true/false
				static if(!is(T == bool)) {
					assert(false, "NODELAY value type must be bool, not " ~ T.stringof);
				} else {
					int val;
					uint len = val.sizeof;
					err = getsockopt(socket, IPPROTO_TCP, TCP_NODELAY, &val, &len);
					value = val ? true : false;
					return errorHandler();
				}
			case TCPOption.REUSEADDR: // true/false
				static if(!is(T == bool)) {
					assert(false, "REUSEADDR value type must be bool, not " ~ T.stringof);
				} else {
					int val;
					uint len = val.sizeof;
					err = getsockopt(socket, SOL_SOCKET, SO_REUSEADDR, &val, &len);
					value = val ? true : false;
					return errorHandler();
				}
			case TCPOption.REUSEPORT: // true/false
				static if(!is(T == bool)) {
					assert(false, "REUSEADDR value type must be bool, not " ~ T.stringof);
				} else {
					int val;
					uint len = val.sizeof;
					err = getsockopt(socket, SOL_SOCKET, SO_REUSEPORT, &val, &len);
					value = val ? true : false;
					return errorHandler();
				}
			case TCPOption.KEEPALIVE_ENABLE: // true/false
				static if(!is(T == bool)) {
					assert(false, "KEEPALIVE_ENABLE value type must be bool, not " ~ T.stringof);
				} else {
					int val;
					uint len = val.sizeof;
					err = getsockopt(socket, SOL_SOCKET, SO_KEEPALIVE, &val, len);
					value = val ? true : false;
					return errorHandler();
				}
			case TCPOption.KEEPALIVE_COUNT: // ##
				static if(!isIntegral!T) {
					assert(false, "KEEPALIVE_COUNT value type must be integral, not " ~ T.stringof);
				} else {
					int val;
					uint len = val.sizeof;
					err = getsockopt(socket, IPPROTO_TCP, TCP_KEEPCNT, &val, len);
					value = cast(T)val;
					return errorHandler();
				}
			case TCPOption.KEEPALIVE_INTERVAL: // wait ## seconds
				static if(!is(T == Duration)) {
					assert(false, "KEEPALIVE_INTERVAL value type must be Duration, not " ~ T.stringof);
				} else {
					int val;
					uint len = val.sizeof;
					err = getsockopt(socket, IPPROTO_TCP, TCP_KEEPINTVL, &val, len);
					value = dur!"seconds"(val);
					return errorHandler();
				}
			case TCPOption.KEEPALIVE_DEFER: // wait ## seconds until start
				static if(!is(T == Duration)) {
					assert(false, "KEEPALIVE_DEFER value type must be Duration, not " ~ T.stringof);
				} else {
					int val;
					uint len = val.sizeof;
					err = getsockopt(socket, IPPROTO_TCP, TCP_KEEPIDLE, &val, len);
					value = dur!"seconds"(val);
					return errorHandler();
				}
			case TCPOption.BUFFER_RECV: // bytes
				static if(!isIntegral!T) {
					assert(false, "BUFFER_RECV value type must be integral, not " ~ T.stringof);
				} else {
					int val;
					uint len = val.sizeof;
					err = getsockopt(socket, SOL_SOCKET, SO_RCVBUF, &val, len);
					value = cast(T)val;
					return errorHandler();
				}
			case TCPOption.BUFFER_SEND: // bytes
				static if(!isIntegral!T) {
					assert(false, "BUFFER_SEND value type must be integral, not " ~ T.stringof);
				} else {
					int val;
					uint len = val.sizeof;
					err = getsockopt(socket, SOL_SOCKET, SO_SNDBUF, &val, len);
					value = cast(T)val;
					return errorHandler();
				}
			case TCPOption.TIMEOUT_RECV:
				static if(!is(T == Duration)) {
					assert(false, "TIMEOUT_RECV value type must be Duration, not " ~ T.stringof);
				} else {
					/*import core.sys.posix.sys.time : timeval;
					 timeval t;
					 uint len = t.sizeof;
					 err = setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &t, len);
					 value = dur!"seconds"(val);
					 */
					return false;//errorHandler();
				}
			case TCPOption.TIMEOUT_SEND:
				static if(!is(T == Duration)) {
					assert(false, "TIMEOUT_SEND value type must be Duration, not " ~ T.stringof);
				} else {
					/*import core.sys.posix.sys.time : timeval;
					 timeval t;
					 uint len = t.sizeof;
					 err = getsockopt(socket, SOL_SOCKET, SO_SNDTIMEO, &t, len);*/
					return false;//errorHandler();
				}
			case TCPOption.TIMEOUT_HALFOPEN:
				static if(!is(T == Duration)) {
					assert(false, "TIMEOUT_SEND value type must be Duration, not " ~ T.stringof);
				} else {
					uint val;
					uint len = val.sizeof;
					err = getsockopt(socket, SOL_SOCKET, SO_SNDTIMEO, &val, len);
					value = dur!"msecs"(val);
					return errorHandler();
				}
			case TCPOption.LINGER: // bool onOff, int seconds
				static if(!is(T == Tuple!(bool, int))) {
					assert(false, "LINGER value type must be Tuple!(bool, int), not " ~ T.stringof);
				} else {
					linger l ;//= linger(val[0]?1:0, val[1]);
					uint llen = l.sizeof;
					err = getsockopt(socket, SOL_SOCKET, SO_LINGER, &l, llen);
					value[0] = l.l_onoff ? true : false;
					value[0] = l.l_linger;
					return errorHandler();
				}
			case TCPOption.CONGESTION:
				static if(!isIntegral!T) {
					assert(false, "CONGESTION value type must be integral, not " ~ T.stringof);
				} else {
					int val;
					len = int.sizeof;
					err = getsockopt(socket, IPPROTO_TCP, TCP_CONGESTION, &val, len);
					value = cast(T)val;
					return errorHandler();
				}
			case TCPOption.CORK:
				static if(!isIntegral!T) {
					assert(false, "CORK value type must be int, not " ~ T.stringof);
				} else {
					int val = value;
					uint len = val.sizeof;
					err = getsockopt(socket, IPPROTO_TCP, TCP_CORK, &val, len);
					value = cast(T)val;
					return errorHandler();
					
				}
			case TCPOption.DEFER_ACCEPT: // seconds
				static if(!isIntegral!T) {
					assert(false, "DEFER_ACCEPT value type must be integral, not " ~ T.stringof);
				} else {
					int val;
					uint len = val.sizeof;
					err = getsockopt(socket, IPPROTO_TCP, TCP_DEFER_ACCEPT, &val, len);
					value = cast(T)val;
					return errorHandler();
				}
		}
		
	}
	

protected :
	/** 设置当前TCP是否为异步 */
	@property asynchronous(bool value) {
		int nNoBlocking;
		if(value) {
			version (Posix) {
				int old = fcntl(fd, F_GETFL, 0);

				if((nNoBlocking = fcntl(fd, F_SETFL, old | O_NONBLOCK)) < 0) {
					error("set fd ",fd," async failed");
				}
			}
		} else {
			version (Posix) {
				int old = fcntl(fd, F_GETFL, 0);

				if((nNoBlocking = fcntl(fd, F_SETFL, old & ~O_NONBLOCK)) < 0) {
					error("set fd ",fd ," unasync failed");
				}
			}
		}
	}

}
