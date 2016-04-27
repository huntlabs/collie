module collie.channel.ssllistener;
version(SSL):


//import std.concurrency;
import core.thread;
import core.atomic;
import core.sync.mutex;

import std.string;

import collie.channel;

import deimos.openssl.ssl;

version(USE_SSL_V2) {
	enum SSLMODE
	{
		SSLv2,
		SSLv3,
		SSLv2v3,
		TLSv1,
		TLSv1_1,
		TLSv1_2
	}
} else {
	enum SSLMODE
	{
		SSLv3,
		SSLv2v3,
		TLSv1,
		TLSv1_1,
		TLSv1_2
	}
}

class SSLlistener : Channel
{
	alias sslconnectionHandler = void delegate(SSLSocket);
	/** 构造函数
	 @param : loop = 所属的事件循环。
	 */
	this(EventLoop loop, SSLMODE mod = SSLMODE.SSLv2v3)
	{
		super(loop);
		type = CHANNEL_TYPE.SSL_Listener;
		_mode = mod;
		final switch(_mode) {
			version(USE_SSL_V2) {
				case  SSLMODE.SSLv2:
					_sslCtx = SSL_CTX_new(SSLv2_method());
					break;
			}
			case SSLMODE.SSLv3:
				_sslCtx = SSL_CTX_new(SSLv3_method());
				break;
			case SSLMODE.SSLv2v3:
				_sslCtx = SSL_CTX_new(SSLv23_method());
				break;
			case SSLMODE.TLSv1:
				_sslCtx = SSL_CTX_new(TLSv1_method());
				break;
			case SSLMODE.TLSv1_1:
				_sslCtx = SSL_CTX_new(TLSv1_1_method());
				break;
			case SSLMODE.TLSv1_2:
				_sslCtx = SSL_CTX_new(TLSv1_2_method());
				break;
		}
	}
	
	/** 析构函数 */
	~this()
	{
		onClose();
		SSL_CTX_free(_sslCtx);
	}

	void setConnectHandler(sslconnectionHandler handler)
	{
		assert(handler);
		_block = handler;
	}

	bool setCertificateFile(string file)
	{
		auto r = SSL_CTX_use_certificate_file(_sslCtx,toStringz(file) , SSL_FILETYPE_PEM);
		if(r < 0) {
			error("SSL_CTX_use_certificate_file failed ! file : ",file);
			return false;
		}
		return true;
	}

	bool setPrivateKeyFile(string file)
	{
		auto r = SSL_CTX_use_PrivateKey_file(_sslCtx, toStringz(file), SSL_FILETYPE_PEM);
		if(r < 0) {
			error("SSL_CTX_use_PrivateKey_file failed! file : ",file);
			return false;
		}
		r = SSL_CTX_check_private_key(_sslCtx);
		if(r < 0) {
			error( "SSL_CTX_check_private_key failed");
			return false;
		}
		return true;
	}

	bool setCipherList(string cipher)
	{
		int i = SSL_CTX_set_cipher_list(_sslCtx, toStringz(cipher));
		return i == 1 ? true : false;
	}

	@property SSL_CTX* sslCtx() { return _sslCtx; }
	@property SSLMODE sslMode() { return _mode; }
	
	mixin TCPListenMixin!(SSLSocket);
	mixin SocketOption!();

protected:
	override void onRead()
	{
		trace(" onRead the thread is = ",to!string(Thread.getThis().name));
		Address addr;
		if(this._isIpv6) {
			addr.family = AF_INET6;
		} else {
			addr.family = AF_INET;
		}
		int tfd;
		uint lenght = addr.sockAddrLen;
		SSLSocket sslSocket = null;
		while(!isInValid()) {
			tfd =  accept(fd, addr.sockAddr,&lenght);

			if(tfd > 0) {
				auto ssl = SSL_new (_sslCtx);
				auto r = SSL_set_fd(ssl, tfd);
				if(r < 0) {
					error("SSL_set_fd error: fd = ",tfd);
					SSL_shutdown (ssl);
					SSL_free(ssl);
					continue;
				}
				SSL_set_accept_state(ssl);
				version(TCP_POOL) {
					if(SSLPool.empty) {
						sslSocket = new SSLSocket(eventLoop, tfd,ssl);
					} else {
						sslSocket = SSLPool.deQueue();
						sslSocket.reset(eventLoop, tfd,ssl);
					}
				} else {
					sslSocket = new SSLSocket(eventLoop, tfd,ssl);
				}

				sslSocket.remoteAddress = addr;
				
				trace("remote client ", addr.getIp(), ":" ,addr.getPort(),  "connected with fd : ", sslSocket.fd);
				
				/* 给应用层进行回调 */
				_block(sslSocket);
				if(!sslSocket._start) {
					sslSocket.close();
					version(TCP_POOL) {
						SSLPool.enQueue(sslSocket);
					}
				} else {
					linkMap[tfd] = sslSocket;
					sslSocket.listener = this;
					sslSocket.status(sslSocket.status);
				}
			} else {
				if(errno == EAGAIN || errno == ECONNABORTED || errno == EPROTO || errno == EINTR || errno == EWOULDBLOCK) {
					break;
				} else {
					error("socket accpet failure %d", errno);
					if( _accept && !_accept(errno)) {
						onClose();
					}
					break;
				}
				
			}
		}
	}
private:
	SSL_CTX* _sslCtx;
	SSLMODE _mode;
	sslconnectionHandler _block;
}

import deimos.openssl.opensslv;
import deimos.openssl.crypto;

//import std.stdio;
shared static this()
{
	SSL_load_error_strings ();
	SSL_library_init ();
	sslmutex.length = CRYPTO_num_locks();
	for(uint i = 0; i < sslmutex.length; ++i) {
		sslmutex[i] = new Mutex();
		//writeln("new mutex");
	}
	static if(OPENSSL_VERSION_NUMBER > 0x10000000L) {
		CRYPTO_THREADID_set_callback(&threadid_function);
	} else {
		CRYPTO_set_id_callback(&id_function);
	}
	CRYPTO_set_locking_callback(&ssl_lock_callback);
}

shared static ~this()
{
	static if(OPENSSL_VERSION_NUMBER > 0x10000000L) {
		CRYPTO_THREADID_set_callback(null);
	} else {
		CRYPTO_set_id_callback(null);
	}
	CRYPTO_set_locking_callback(null);
}

private {
	__gshared Mutex[] sslmutex;
}
extern(C) :
ulong id_function()
{
	return Thread.getThis.id;
}

void threadid_function(CRYPTO_THREADID* id)
{
	CRYPTO_THREADID_set_numeric(id, Thread.getThis.id);
}

void ssl_lock_callback(int mode, int type, const(char) * file, int line)
{
	if(mode & CRYPTO_LOCK) {
		sslmutex[type].lock();
	//	writeln("SSL LOCK");
	} else {
		sslmutex[type].unlock();
	//	writeln("un SSL LOCK");
	}
}
