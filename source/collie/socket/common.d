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
module collie.socket.common;

//import core.memory;

public import std.experimental.logger;
import std.experimental.allocator;

import collie.socket.eventloop;

enum TCP_READ_BUFFER_SIZE = 4096;

enum TransportType : short
{
    ACCEPT,
    TCP,
    UDP
}

abstract class AsyncTransport
{
    this(EventLoop loop)
    {
        _loop = loop;
    }

    void close();
    bool start();
    @property bool isAlive() @trusted;
    @property int fd();

    final @property eventLoop()
    {
        return _loop;
    }

protected:
    EventLoop _loop;
}

alias CallBack = void delegate();

enum AsynType
{
    ACCEPT,
    TCP,
    UDP,
    EVENT,
    TIMER
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

    this(AsynType type, EventCallInterface obj, socket_t fd = socket_t.init,
        bool enread = true, bool enwrite = false, bool etMode = false, bool oneShot = false)
    {
        this._type = type;
        this._obj = obj;
        this.fd = fd;
        this.enRead = enread;
        this.enWrite = enwrite;
        this.etMode = etMode;
        this.oneShot = oneShot;
    }

    pragma(inline,true)
    @property obj()
    {
        return _obj;
    }

    pragma(inline,true)
    @property type()
    {
        return _type;
    }

    socket_t fd;

    bool enRead = true;
    bool enWrite = false;
    bool etMode = false;
    bool oneShot = false;
    bool deleteOnClosed = false;

    pragma(inline)
    static AsyncEvent* create(AsynType type, EventCallInterface obj,
        socket_t fd = socket_t.init, bool enread = true, bool enwrite = false,
        bool etMode = false, bool oneShot = false)
    {
        import core.memory;
        AsyncEvent * pevent = new AsyncEvent(type, obj, fd, enread, enwrite, etMode, oneShot);
        GC.setAttr(pevent,GC.BlkAttr.NO_MOVE);
        return pevent;
    }

    pragma(inline)
    static void free(AsyncEvent* event)
    {
        import core.memory;
        GC.free(event);
    }

    pragma(inline,true)
    @property isActive()
    {
        return _isActive;
    }

package:
    pragma(inline)
    @property isActive(bool active)
    {
        _isActive = active;
    }
    
static if(IOMode == IOMode.kqueue)
{
    long timeOut;
}

private:
    EventCallInterface _obj;
    AsynType _type;
    bool _isActive = false;
}
