/* Copyright collied.org 
*/

module collie.channel.define;

public import std.experimental.logger;
public import std.experimental.allocator;
import std.experimental.allocator.mallocator ;

import std.stdio;

static this()
{
	threadColliedAllocator = allocatorObject(AlignedMallocator.instance);
}

shared static this()
{
	colliedAllocator = allocatorObject(AlignedMallocator.instance);
}

__gshared IAllocator colliedAllocator;
IAllocator threadColliedAllocator;

/**
 * 定义socket的类型,因为listener和connection将都是基于socket
 */
enum CHANNEL_TYPE
{
	TCP_Listener, /**< tcp listen类型，用于监听端口，接受TCP链接 */
	TCP_Socket, /**< tcp Socket类型，TCP链接的实例 */
	UDP_Socket, /**< tcp Socket类型 */
	SSL_Listener,
	SSL_Socket,
	Timer, /**< 定时器类型 */
	Event /**< 事件类型 */
}

/**
 * 定义定义服务的状态
 */
enum SOCKET_STATUS
{
	CONNECTED, /**< 已经链接 */
	CONNECTING, /**< 正在连接 */
	ERROR, /**< 错误 */
	SSLHandshake,
	CLOSING, /**< 正在关闭 */
	CLOSED, /**< 已关闭 */
	IDLE  /**< 初始化类型 */
}
package:
version (Posix) 
{
	public import core.sys.posix.fcntl;
	public import core.sys.posix.unistd;
	public import core.sys.posix.sys.socket;
	public import core.sys.posix.netinet.in_;
	public import core.sys.posix.netinet.tcp;
	public import core.sys.posix.sys.stat;
	public import core.sys.posix.sys.un;
	public import core.stdc.errno;
	public import core.stdc.string;
	public import core.sync.mutex;
}
public import std.format;
public import std.functional : toDelegate;

public import core.sync.mutex;

/**
 * 定义接收数据的缓存 
 */
enum MESSAGE_LEGNTH = 4096;

enum SEND_QUEUE_SIZE = 100;

enum TCP_POOL_SIZE_ONE_THREAD = 500;


/** 写完成一次数据的回调
 * @param : size_t 写完一个包的数据的大小，如果出错返回0或-1
 * @param : bool 当前发送队列是不是为空
*/
alias WriteHandler = void delegate (ubyte[],uint);
/** 读取完成一次数据的回调，如果出错也调用
 * @param : ubyte[] 读取数据存储的ubyte数组，可直接操作更改。
 *************************************************/
alias ReadHandler = void delegate (ubyte[]);

alias CloseHandler = void delegate (ubyte[][]);

/** 无返回值的一般callback */
alias CallBack = void delegate ();

alias StatusCallBck = void delegate(SOCKET_STATUS sfrom,SOCKET_STATUS sto);

version(TCP_POOL)  :
import collie.channel.utils.queue;
import collie.channel.tcpsocket;
version(SSL) {
	import collie.channel.sslsocket;
}


static this() {
	_tcpPool = SqQueue!TCPSocket(TCP_POOL_SIZE_ONE_THREAD);
	version(SSL) {
		_sslPool = SqQueue!SSLSocket(TCP_POOL_SIZE_ONE_THREAD);
	}
}

@property SqQueue!TCPSocket * TCPPool(){
	return &_tcpPool;
}
version(SSL) {
	@property SqQueue!SSLSocket * SSLPool(){
		return &_sslPool;
	}
}

private:
SqQueue!TCPSocket _tcpPool;
version(SSL) {
	SqQueue!SSLSocket _sslPool;
}
