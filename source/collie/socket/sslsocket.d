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
module collie.socket.sslsocket;

version(USE_SSL) :

import core.stdc.errno;
import core.stdc.string;

import std.string;
import std.socket;
import std.exception;
import std.experimental.logger;

import collie.socket.eventloop;
import collie.socket.common;
import collie.socket.transport;
import collie.socket.tcpsocket;
import collie.utils.exception;

import deimos.openssl.ssl;
import deimos.openssl.bio;



@trusted class SSLSocket : TCPSocket
{
	static if (IOMode == IO_MODE.iocp){
		this(EventLoop loop, Socket sock, SSL* ssl,BIO * bioRead, BIO * bioWrite){
			super(loop, sock);
			_ssl = ssl;
			_bioIn = bioRead;
			_bioOut = bioWrite;
			_rBuffer = new ubyte[TCP_READ_BUFFER_SIZE];
			_wBuffer = new ubyte[TCP_READ_BUFFER_SIZE];
		}
	} else {
		this(EventLoop loop, Socket sock, SSL* ssl)
		{
			super(loop, sock);
			_ssl = ssl;
		}
	}

	~this()
	{
		if (_ssl){
			SSL_shutdown(_ssl);
			SSL_free(_ssl);
			_ssl = null;
			static if (IOMode == IO_MODE.iocp){
				BIO_free(_bioIn);
				BIO_free(_bioOut);
			}
		}
		static if (IOMode == IO_MODE.iocp){
			import core.memory;
			GC.free(_rBuffer.ptr);
			GC.free(_wBuffer.ptr);
		}
	}

	override @property bool isAlive() @trusted nothrow
	{
		return alive() && _isHandshaked;
	}

	pragma(inline) void setHandshakeCallBack(CallBack cback)
	{
		_handshakeCback = cback;
	}

protected:
	override void onClose(){
		if (_ssl){
			SSL_shutdown(_ssl);
			SSL_free(_ssl);
			_ssl = null;
			static if (IOMode == IO_MODE.iocp){
				BIO_free(_bioIn);
				BIO_free(_bioOut);
			}
		}
		super.onClose();
	}
	static if (IOMode == IO_MODE.iocp){

		override void onWrite(){
			if (!alive)
				return;
			if(writeBIOtoSocket() || _writeQueue.empty ) return;
			try{
				auto buffer = _writeQueue.front;
				auto len = SSL_write(_ssl, buffer.data.ptr, cast(int)buffer.length);   // data中存放了要发送的数据
				if (len > 0) {
					if (buffer.add(len)){
						_writeQueue.deQueue().doCallBack();
					}
				} 
				writeBIOtoSocket();
			} catch(Exception e){
				showException(e);
			}
		}
		override void onRead(){
			try
			{
				
				trace("read data : data.length: ", _event.readLen);
				if (_event.readLen > 0){
					BIO_write(_bioIn, _readBuffer.ptr, cast(int)_event.readLen);
					if (!_isHandshaked){
						if (!handlshake()){
							return;
						}
						onWrite();
					}
					while(true) {
						int ret = SSL_read(_ssl, _rBuffer.ptr, cast(int)_rBuffer.length);
						if (ret > 0) {
							_readCallBack(_rBuffer[0 .. ret]);
						}
						if(ret < _rBuffer.length)
							break;
					}
				} else {
					onClose();
					return;
				}
			}
			catch(Exception e)
			{
				showException(e);
			}
			_event.readLen = 0;
			if (alive)
				doRead();
		}
		bool writeBIOtoSocket() nothrow {
			int hasread = BIO_read(_bioOut, _wBuffer.ptr, cast(int)_wBuffer.length);
			if (hasread > 0) {
				_iocpWBuf.len = hasread;
				_iocpWBuf.buf = cast(char*) _wBuffer.ptr;
				doWrite();
				return true;
			}
			return false;
		}
	} else {
		override void onWrite()
		{
			if (alive && !_isHandshaked)
			{
				if (!handlshake())
					return;
			}
			try{
				while (alive && !_writeQueue.empty) {
					auto buffer = _writeQueue.front;
					auto len = SSL_write(_ssl, buffer.data.ptr, cast(int) buffer.length); // _socket.send(buffer.data);
					if (len > 0) {
						if (buffer.add(len)){
							_writeQueue.deQueue().doCallBack();
						}
						continue;
					} else {
						int sslerron = SSL_get_error(_ssl, len);
						if (sslerron == SSL_ERROR_WANT_READ || errno == EWOULDBLOCK
							|| errno == EAGAIN)
							break;
						else if (errno == 4 ) // erro 4 :系统中断组织了
							continue;
					}
					error("write size: ",len," \n\tDo Close the erro code : ", errno, "  erro is : " ,fromStringz(strerror(errno)), 
						" \n\tthe socket fd : ", fd);
					onClose();
					return;
				}
			} catch (Exception e) {
				import collie.utils.exception;
				showException(e);
				onClose();
				return;
			}
		}

		override void onRead()
		{
			try
			{
				while (alive){
					if (!_isHandshaked){
						if (!handlshake())
							return;
					}
					auto len = SSL_read(_ssl, (_readBuffer.ptr), cast(int)(_readBuffer.length));
					if (len > 0){
						collectException(_readCallBack(_readBuffer[0 .. len]));
						continue;
					} else if(len < 0) {
						int sslerron = SSL_get_error(_ssl, len);
						if (sslerron == SSL_ERROR_WANT_READ || errno == EWOULDBLOCK
							|| errno == EAGAIN)
							break;
						else if (errno == 4) // erro 4 :系统中断组织了
							continue;
						import core.stdc.string;
						error("Do Close the erro code : ", errno, "  erro is : " ,fromStringz(strerror(errno)), 
							" \n\tthe socket fd : ", fd);
					}
					onClose();
					return;
				}
			}
			catch (Exception e)
			{
				import collie.utils.exception;
				showException(e);
				onClose();
			}
		}
	}
	final bool handlshake() nothrow
	{
		int r = SSL_do_handshake(_ssl);
		static if (IOMode == IO_MODE.iocp){
			writeBIOtoSocket();
		}
		if (r == 1)
		{
			//collectException(trace("ssl connected fd : ", fd));
			_isHandshaked = true;
			if (_handshakeCback)
			{
				collectException(_handshakeCback());
			}
			return true;
		}
		int err = SSL_get_error(_ssl, r);
		if (err == SSL_ERROR_WANT_WRITE)
		{
			//collectException(trace("return want write fd = ", fd));
			static if (IOMode == IO_MODE.iocp){
				writeBIOtoSocket();
			}
			return false;
		}
		else if (err == SSL_ERROR_WANT_READ)
		{
			//collectException(trace("return want read fd = ", fd));
			return false;
		}
		else
		{
			collectException(trace("SSL_do_handshake return: ", r, "  erro :", err,
					"  errno:", errno, "  erro string:", fromStringz(strerror(errno))));
			onClose();
			return false;
		}
	}

protected:
	bool _isHandshaked = false;

private:
	SSL* _ssl;
	CallBack _handshakeCback;
	static if (IOMode == IO_MODE.iocp){
		BIO * _bioIn;
		BIO * _bioOut;
		ubyte[] _rBuffer;
		ubyte[] _wBuffer;
	}
}

