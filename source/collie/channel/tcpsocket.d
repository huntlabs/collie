/* Copyright collied.org 
 */


module collie.channel.tcpsocket;

public import std.datetime;

import collie.channel;
import collie.channel.utils.queue;
import collie.channel.utils.buffer;

/** Tcp 异步链接类
 @authors  Putao‘s Collie Team
 @date  2016.1
 */

final class TCPSocket : Channel //添加客户端的链接之类的逻辑
{
public :
	/** 构造函数
	 @param : loop = 所属的事件循环。
	 */
	this (EventLoop loop)
	{
		this(loop,-1);
	}
	/** 析构函数 */
	~this ()
	{
		onClose();
		colliedAllocator.deallocate(_recvBuffer);
	}

	/** 关闭socket */
	void close() {
		if(!_start && !isInValid()) {
			.close(fd);
			_status = SOCKET_STATUS.IDLE;
		} else { 
			onClose();
		}
	}
	/** 混入Socket 选项模板 */
	mixin SocketOption!();

	mixin TCPSocketMixin!(TCPListener);

package:
	/** 构造函数
	 @param : loop = 所属的事件循环。
	 @param : socket = 此socket管理的FD。
	 */
	this (EventLoop loop, int socket)
	{
		super(loop);
		type = CHANNEL_TYPE.TCP_Socket;
		fd = socket;
		if(!this.isInValid()) {
			asynchronous = true;
			_status = SOCKET_STATUS.CONNECTED;
		}
		_recvBuffer = cast(ubyte[])colliedAllocator.allocate(MESSAGE_LEGNTH);//new ubyte[MESSAGE_LEGNTH];//
		_sendQueue = SqQueue!(WriteBuffer,true)(SEND_QUEUE_SIZE);
	}

	void reset(EventLoop loop,int tfd) {
		fd  = tfd;
		eventLoop = loop;
		_status = SOCKET_STATUS.CONNECTED;
	}

protected:
	/** 有可读事件时调用的函数。
	 @note : 用原子实现的同步，即使多个线程同时跑事件循环，也保证同时只有一个线程在执行次函数。
	 */
	final override void onRead () 
	{
		trace("  onread");
		ssize_t length = 0;
		while (!isInValid())
		{
			length = .read(fd, _recvBuffer.ptr, _recvBuffer.length);
			trace("tcp on read: ",length);
			if (length > 0) {
				trace("tcp on read data = : ", _recvBuffer[0..length]);
				_recvHandler(_recvBuffer[0..length]);
			} else {
				if (errno == EWOULDBLOCK || errno == EAGAIN ){ // erro 4 :系统中断组织了
					break;
				} else if(errno == 4) {
					continue;
				} else {
					error("read ", fd, "failure with ", errno);
					onClose();
					return;
				}
			}
		} 
	}

	/** 从事件循环中移除socket并关闭 */
	final override void onClose ()
	{
		if (isInValid()){
			return;
		}
		if(!_start) {
			.close(fd);
			return;
		}
		clearListenr();
		_start = false;
		eventLoop.delEvent(this);
		fd = -1;
		if(!_sendQueue.empty){
			scope ubyte[][] buffer = new ubyte[][_sendQueue.length];
			int i = 0;
			while(!_sendQueue.empty){
				buffer[i] = _sendQueue.deQueue().allData;
				++i;
			}
			_callBack(buffer);
		} else {
			_callBack(null);
		}
		/* 此时把socket连接的状态职位closed */
		status = SOCKET_STATUS.CLOSED;
	}

	/** 有可写事件时调用的函数。*/
	final override void onWrite ()
	{
		trace("  onWrite");
		if(status == SOCKET_STATUS.CONNECTING) { 
			status(SOCKET_STATUS.CONNECTED);
		}
		if(_sendQueue.empty) return;
		doWrite();
	}
protected:
	/** 执行socket写入。
	 */
	final void doWrite()
	{
		ssize_t length = 0;
		WriteBuffer buffer;
		while(!isInValid() && !_sendQueue.empty) {
			buffer = _sendQueue.front();
			length = .write(fd, buffer.data.ptr, buffer.dataSize);
			if (length >  0) {
				if (length < buffer.dataSize) {
					buffer._start += length;
					break;
				} else {
					_sendQueue.deQueue();
					_sendHandler(buffer.allData,cast(uint)buffer.allData.length);
					continue;
				}
			} else  {
				if (errno == EWOULDBLOCK || errno == EAGAIN)
				{
					break;
				} else if (errno == 4){
					continue;
				}else{
					onClose();
				}
			}

		} 
	}

}


mixin template TCPSocketMixin(T)
{
private:
	Address 					_address;		// socket's address
	
	ReadHandler				_recvHandler = null;		// recv's delegate
	WriteHandler				_sendHandler = null;		// send's delegate
	CloseHandler				_callBack = null;	// just call back with (void *) when you needed
	
	ubyte[] 			_recvBuffer;	// recvBuffer for recv
	
	SqQueue!(WriteBuffer,true)		_sendQueue;	// send's vector
	
	SOCKET_STATUS	_status = SOCKET_STATUS.IDLE;	// socket's status
	StatusCallBck				_statusHandler = null;

package :
	/** 设置当前socket的状态 */
	@property status (SOCKET_STATUS sStatus)
	{
		auto s = _status;
		_status = sStatus;
		if(_statusHandler)
			_statusHandler(s,_status);
	}
	
	@property void remoteAddress(Address adr){_address = adr;}

	bool      _start = false;

	T listener;
public:

	bool isInListener(){return (listener !is null);}

	void clearListenr(){
		if(isInListener()) {
			listener.linkMap[fd] = null;
			listener.linkMap.remove(fd);
		//	import std.stdio;
		//	writeln("socket closed fd: ", fd, "   listMap size : ",listener.linkMap.length);
		//	listener = null;
		}
	}

	/** 链接到服务器 */
	
	bool connect(Address adr)
	{
		if(!_statusHandler) return false;
		_address = adr;
		onClose();
		_status = SOCKET_STATUS.IDLE;
		if (_address.isIpV6) {
			fd = socket(AF_INET6, SOCK_STREAM, IPPROTO_IP);
		} else {
			fd = socket(AF_INET, SOCK_STREAM, IPPROTO_IP);
		}
		if (isInValid())
		{
			error("create socket error");
			return false;
		}
		start();
		int ru = .connect(fd,_address.sockAddr,_address.sockAddrLen);
		status = SOCKET_STATUS.CONNECTING;
		if (ru < 0 && errno != EINPROGRESS)
			return false;
		return true;
	}

	/** 设置有数据时的回调 */
	void readHandler (const ReadHandler  handler)
	{
		assert (handler);
		
		_recvHandler = handler;
	}
	
	/** 设置数据写入成功时的回调 */
	void writeHandler (const WriteHandler handler)
	{
		assert (handler);
		
		_sendHandler = handler;
	}
	
	/** 设置数据关闭时的回调 */
	void colsedHandler (const CloseHandler callBack)
	{
		assert (callBack);
		
		_callBack = callBack;
	}


	void statusHandler(const StatusCallBck con)
	{
		assert(con);
		_statusHandler = con;
	}

	
	/** 发送数据。
	 @param : data = 要所发送的数据。
	 @note : 数据会被内部保存和使用，请传过来后不要再对次数据进行操作。如果改变数据，则发送的的数据可能是不确定的。
	 */
	bool write(ubyte[] data)
	{
		//info("tcp write data = ", data);
		trace("write data!");

		if (data.length == 0 || isInValid || status != SOCKET_STATUS.CONNECTED)
		{
			error("data's length is 0 when write");
			
			return false;
		}
		if(!_sendQueue.enQueue(WriteBuffer(data))) return false;
		doWrite();

		return true;
	}
	
	/** 禁用默认构造函数 */
	@disable this ();
	
	
	/** 返回当前socket的状态 */
	@property status ()
	{
		return _status;
	}
	
	@property Address remoteAddress(){return _address;}
	
	/** 把socket加入到事件队列中，开始监听其事件。
	 @param : 要加到的事件队列。如果为null则为构造时的事件队列。
	 @return ： 如果已经在事件队列中或者socket无效，则返回false，成功返回true。
	 */
	bool start(EventLoop loop = null) {
		if (!_start && !isInValid ()) {
			if (loop !is null) {
				eventLoop = loop;
			}
			eventLoop.addEvent(this);
			_start = true;
			return true;
		}
		return false;
	}

}


unittest
{
	import std.stdio;
	EventLoop  loop = new EventLoop();
	TCPSocket soc = new TCPSocket(loop);
	Address addr = Address("127.0.0.1",8194);
	void connectH(bool istrue)
	{
		writeln("Connect CallBack : ",to!string(istrue));
	}
	soc.connectHandler(&connectH);
	soc.connect(addr);
	//writeln("start  loop!");
	int i = 100;
	while(i) {
		loop.run(200000);
	}
}
