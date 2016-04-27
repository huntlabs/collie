/* Copyright collied.org 
 */

module collie.channel.tcplistener;

//import std.concurrency;
import core.thread;
import core.atomic;
import core.sync.mutex;

import collie.channel;

/** Tcp 监听并异步接受链接的类
 @authors  Putao‘s Collie Team
 @date  2016.1
 */

final class TCPListener : Channel
{
	/**
	 * 设置应用层TCPConnection的代理函数
	 */
	alias connectionHandler = void delegate(TCPSocket);

	/** 构造函数
	 @param : loop = 所属的事件循环。
	 */
	this(EventLoop loop)
	{
		super(loop);
		type = CHANNEL_TYPE.TCP_Listener;
	}

	/** 析构函数 */
	~this()
	{
		onClose();
	}

	void setConnectHandler(connectionHandler handler)
	{
		assert (handler);
		_block = handler;
	}

	mixin TCPListenMixin!(TCPSocket);
	/** 混入Socket 选项模板 */
	mixin SocketOption!();
protected:
	/** 有新链接调用的函数。
	 @note : 注意：如果事件循环在多个线程中执行，那么此函数可能会同时执行。
	 */
	override void onRead()
	{
		trace("===========have new connect! @ onRead the thread is = ",to!string(Thread.getThis().name));
		Address addr;
		if(this._isIpv6) {
			addr.family = AF_INET6;
		} else {
			addr.family = AF_INET;
		}
		int tfd;
		uint lenght = addr.sockAddrLen;
		TCPSocket tcpSocket = null;
		while(!isInValid()) {
			tfd =  accept(fd, addr.sockAddr,&lenght);
			
			if(tfd > 0) {
				version(TCP_POOL) {
					pragma(msg, "\n\t used TCP_POLL \n");
					if(TCPPool.empty) {
						tcpSocket = new TCPSocket(eventLoop, tfd);
					} else {
						tcpSocket = TCPPool.deQueue();
						tcpSocket.reset(eventLoop, tfd);
					}
				} else {
					tcpSocket = new TCPSocket(eventLoop, tfd);
				}

				tcpSocket.remoteAddress = addr;
				/* 给应用层进行回调 */
				_block(tcpSocket);
				if(!tcpSocket._start) {
					tcpSocket.close();
					version(TCP_POOL) {
						TCPPool.enQueue(tcpSocket);
					}
				} else {
					linkMap[tfd] = tcpSocket;
					tcpSocket.listener = this;
					tcpSocket.status(tcpSocket.status);
				}			
			} else {
				if(errno == EAGAIN || errno == ECONNABORTED || errno == EPROTO || errno == EINTR || errno == EWOULDBLOCK) {
					break;
				} else {
					error("socket accpet failure %d", errno);
					if(_accept && !_accept(errno)) {
						onClose();
					}
					break;
				}
			}
		}
	}

private:
	/// 保存上层的回调
	connectionHandler _block;
	//Timer _tm;
}


mixin template TCPListenMixin(T)
{
	alias TCPListenAccpentError = bool delegate(int);
private:
	/// 保存监听的地址
	Address _address;
	TCPListenAccpentError _accept;
	
	/// 监听的地址是否为ip6
	bool _isIpv6;

protected:
	override void onWrite() {};
	
	/** 关闭监听，并从事件循环中移除。 */
	
	override void onClose()
	{
		if(!isInValid()) {
			eventLoop.delEvent(this);
			auto list  = sockets.keys;
			foreach(i;list) {
				auto ch = linkMap.get(i,null);
				if(ch)
					ch.close();
			}
		}
	}

package:
	T[int] linkMap;
public:

	@property sockets() { return linkMap; }

	/** 绑定并监听地址，开启 REUSEPORT 选项，支持多个同时监听。 
	 @param : addr 需要监听的地址和端口
	 @return ： true 绑定并监听成功。false 不成功。
	 @note ： 此函数只是设置监听 和 把fd加到事件队列中，并不启动事件循环。
	 */
	bool listen(Address addr)
	{
		address = addr;
		if(!isInValid())
			onClose();
		if(address.isIpV6) {
			_isIpv6 = true;
			fd = socket(AF_INET6, SOCK_STREAM, IPPROTO_IP);
		} else {
			_isIpv6 = false;
			fd = socket(AF_INET, SOCK_STREAM, IPPROTO_IP);
		}
		if(isInValid()) {
			error("create socket error");
			return false;
		}
		setOption(TCPOption.NODELAY,true);
		setOption(TCPOption.REUSEPORT,true);
		asynchronous(true);
		if(bind(fd, address.sockAddr, address.sockAddrLen) == -1) {
			error("socket bind faild, errno ", errno);
			return false;
		}

		trace("Listened on bind ");

		if(core.sys.posix.sys.socket.listen(fd, SOMAXCONN) == -1) {
			error("socket listen faild, errno ", errno);
			return false;
		}
		//trace("Listened on ", address.getIp(), " at port ".address.getPort());
		eventLoop.addEvent(this);
		
		return true;
	}
	
	/**
	 * 设置有新链接时的监听函数。
	 */

	void setAcceptErrorHandler(TCPListenAccpentError handler)
	{
		_accept = handler;
	}

	void kill() { onClose(); }
}

unittest {
	/*
	 Address address = new Address("0.0.0.0", 8081);

	 sockaddr_in shit = address.sockAddr;

	 TCPListener listener = new TCPListener(null);
	 listener.listen(address);*/
}
