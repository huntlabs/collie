module collie.channel.sslsocket;
version(SSL):
import collie.channel;
import collie.channel.pipeline;
import collie.channel.utils.queue;
import collie.channel.utils.buffer;
import collie.channel.tcpsocket;

import deimos.openssl.ssl;

final class SSLSocket : Channel {
public:
	/** 构造函数
	 @param : loop = 所属的事件循环。
	 */
/*	this (EventLoop loop) //TODO: ssl暂时不支持客户端
	{
		this(loop,-1);
	}*/
	/** 析构函数 */
	~this() {
		onClose(); 
		colliedAllocator.deallocate(_recvBuffer);
		if(_ssl) {
			SSL_shutdown (_ssl);
			SSL_free(_ssl);
			_ssl = null;
		}
		//import std.stdio:writeln;
		//writeln("~this TCPSocket");
	}
	/** 关闭socket */
	void close() {
		if(!_start && !isInValid()) {
			.close(fd);
			_status = SOCKET_STATUS.IDLE;
			if(_ssl) {
				SSL_shutdown (_ssl);
				SSL_free(_ssl);
				_ssl = null;
			}
		} else { 
			onClose();
		}
	}
	/** 混入Socket 选项模板 */
	mixin SocketOption!();
	mixin TCPSocketMixin!(SSLlistener);
package:
	/** 构造函数
	 @param : loop = 所属的事件循环。
	 @param : socket = 此socket管理的FD。
	 */
	this(EventLoop loop, int socket,SSL * ssl = null) {
		super(loop);
		type = CHANNEL_TYPE.SSL_Socket;
		fd = socket;

		if(!this.isInValid()) {
			asynchronous = true;
			_status = SOCKET_STATUS.SSLHandshake;
		}
		_recvBuffer = cast(ubyte[])colliedAllocator.allocate(MESSAGE_LEGNTH);//new ubyte[MESSAGE_LEGNTH];//
		_sendQueue = SqQueue!(WriteBuffer,true)(SEND_QUEUE_SIZE);
		_ssl = ssl;
	}

	void reset(EventLoop loop,int tfd,SSL * ssl) {
		fd  = tfd;
		eventLoop = loop;
		_ssl = ssl;
		_status = SOCKET_STATUS.SSLHandshake;
	}
protected:
	final override void onRead() { //TODO:
		if(isInValid()) 
			return;
		if(status == SOCKET_STATUS.SSLHandshake) {
			int i = doHandShake();
			if(i == -1) {
				onClose();
			}
			if (i <= 0)
				return;
		}
		int length = 0;
		while(!isInValid() && status == SOCKET_STATUS.CONNECTED) {
			length = SSL_read(_ssl, _recvBuffer.ptr, cast(int)(_recvBuffer.length));
			trace("ssl on read: ",length);
			if (length > 0) {
				_recvHandler(_recvBuffer[0..length]);
			} else {
				int ssle = SSL_get_error(_ssl, length);
				if(ssle == SSL_ERROR_WANT_READ || errno == EWOULDBLOCK || errno == EAGAIN || errno == 4) { // erro 4 :系统中断组织了
					break;
				} else {
					error("read ", fd, "failure with ", errno);
					onClose();
					return;
				}
			}
		} 
	}

	/** 从事件循环中移除socket并关闭 */
	final override void onClose() {
		if(isInValid())
			return;
		if(!_start) {
			.close(fd);
			return;
		}
		clearListenr();
		_start = false;
		eventLoop.delEvent(this);
		if(_ssl) {
			SSL_shutdown (_ssl);
			SSL_free(_ssl);
			_ssl = null;
		}
		fd = -1;
		if(!_sendQueue.empty) {
			scope ubyte[][] buffer = new ubyte[][_sendQueue.length];
			int i = 0;
			while(!_sendQueue.empty) {
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
	final override void onWrite() {
		if (isInValid())
			return;
		if(status == SOCKET_STATUS.IDLE) { 
			status(SOCKET_STATUS.SSLHandshake);
		}
		if(status == SOCKET_STATUS.SSLHandshake) {
			int i = doHandShake();
			if(i == -1)
				onClose();
			if (i <= 0)
				return;
		}
		if(_sendQueue.empty)
			return;
		doWrite();
	}

	void doWrite() {
		trace("do write data!");
		int length = 0;
		WriteBuffer buffer;
		while(!isInValid() && !_sendQueue.empty) {
			buffer = _sendQueue.front();
			length = SSL_write(_ssl, buffer.data.ptr, cast(int)(buffer.dataSize));
			if(length >  0) {
				if(length < buffer.dataSize) {
					buffer._start += length;
					break;
				} else {
					_sendQueue.deQueue();
					_sendHandler(buffer.allData,cast(uint)(buffer.allData.length));
					continue;
				}
			} else  {
				if(errno == EWOULDBLOCK || errno == EAGAIN) {
					break;
				} else if(errno == 4) {
					continue;
				} else {
					onClose();
				}
			}
		}
	}

	int doHandShake() {
		if(status != SOCKET_STATUS.SSLHandshake)
			return false;
		int r = SSL_do_handshake(_ssl);
		if(r == 1) {
			status = SOCKET_STATUS.CONNECTED;
			trace("ssl connected fd : ", fd);
			return 1;
		}
		int err = SSL_get_error(_ssl, r);
		if(err == SSL_ERROR_WANT_WRITE) {
			trace("return want write fd = ", fd);
		} else if(err == SSL_ERROR_WANT_READ) {
			trace("return want read fd = ", fd);
		} else {
			trace("SSL_do_handshake return: ", r,"  erro :" , err,"  errno:", errno, "  erro string:",strerror(errno));
			return -1;
		}
		return 0;
	}
private :
	SSL * _ssl;
}

