module collie.socket.common;

public import std.experimental.logger;

import collie.socket.eventloop;
import std.socket;

enum TCP_READ_BUFFER_SIZE = 4096;

enum TransportType : short
{
    ACCEPT ,
    TCP ,
    UDP
}


abstract class AsyncTransport
{
    this(EventLoop loop){_loop = loop;}

    void close();
    bool start();
    @property bool isAlive() @trusted;
    @property int fd();

    final @property eventLoop(){return _loop;}

    protected :
    EventLoop _loop;
}


alias CallBack = void delegate();

enum AsynType
{
    ACCEPT ,
    TCP ,
    UDP,
    EVENT
}

interface EventCallInterface
{
    void onWrite() nothrow;
    void onRead() nothrow;
    void onClose() nothrow;
}


struct AsyncEvent
{
    import std.socket;

    this(AsynType type,EventCallInterface obj,socket_t fd,bool enread = true, bool enwrite = false, bool etMode = false)
    {
	this.type = type;
	this.obj = obj;
	this.fd = fd;
	this.enRead = enread;
	this.enWrite = enwrite;
	this.etMode = etMode;
    }

    socket_t fd;
    EventCallInterface obj;

    AsynType type;

    bool enRead;
    bool enWrite;
    bool etMode;
}
