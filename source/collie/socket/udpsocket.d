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
module collie.socket.udpsocket;

import core.stdc.errno;

import std.socket;
import std.functional;

import collie.socket.common;
import collie.socket.eventloop;
import collie.socket.transport;
import collie.utils.queue;

import std.stdio;

alias UDPWriteCallBack = void delegate(ubyte[] data, uint writeSzie);
alias UDPReadCallBack = void delegate(ubyte[] buffer, Address adr);

class UDPSocket : AsyncTransport, EventCallInterface
{
    this(EventLoop loop, bool isIpV6 = false)
    {
        super(loop,TransportType.UDP);
        if (isIpV6)
            _socket = new UdpSocket(AddressFamily.INET6);
        else
            _socket = new UdpSocket(AddressFamily.INET);
        _socket.blocking = true;
        _readBuffer = new ubyte[UDP_READ_BUFFER_SIZE];
        _event = AsyncEvent.create(AsynType.UDP, this, _socket.handle, true,
            false, false);
    }
    
    ~this()
    {
        scope (exit)
        {
            AsyncEvent.free(_event);
            _readBuffer = null;
        }
        _socket.destroy;
        if (_event.isActive)
        {
            eventLoop.delEvent(_event);
        }
        import core.memory;
        GC.free(_readBuffer.ptr);
    }
    
    @property reusePort(bool use)
    {
        if (use)
        {
            _socket.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
            version (Posix)
                _socket.setOption(SocketOptionLevel.SOCKET, cast(SocketOption) SO_REUSEPORT,
                    true);
        }
        else
        {
            _socket.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, false);
            version (Posix)
                _socket.setOption(SocketOptionLevel.SOCKET, cast(SocketOption) SO_REUSEPORT,
                    false);

        }
    }
    
    pragma(inline)
    final void setReadCallBack(UDPReadCallBack cback)
    {
        _readCallBack = cback;
    }
    
    void bind(Address addr) @trusted
    {
        _socket.bind(forward!addr);
    }
    
    bool connect(Address to)
    {
        if(!_socket.isAlive()) return false;
        _connecto = to;
        return true;
    }
    
    pragma(inline)
    @safe ptrdiff_t sendTo(const(void)[] buf, Address to)
    {
        return _socket.sendTo(forward!(buf, to));
    }

    pragma(inline)
    @safe ptrdiff_t sendTo(const(void)[] buf)
    {
        ptrdiff_t len  = -1;
        if(_connecto)
            len = _socket.sendTo(forward!(buf), _readAddr);
        return len;
    }
    
    override @property int fd()
    {
        return cast(int) _socket.handle();
    }

    override bool start()
    {
        if (_event.isActive || !_socket.isAlive() || !_readCallBack)
            return false;
        _event.fd = _socket.handle();
        _loop.addEvent(_event);
        return true;
    }
    
    override void close()
    {
        if (isAlive)
        {
           onClose();
        }
        else if (_socket.isAlive())
        {
            _socket.close();
        }
    }

    override @property bool isAlive() @trusted nothrow
    {
        try
        {
            return _event.isActive && _socket.handle() != socket_t.init;
        }
        catch
        {
            return false;
        }
    }

    mixin TransportSocketOption;
    
protected:
    override void onRead() nothrow
    {
        try{
           auto len = _socket.receiveFrom(_readBuffer,_readAddr);
           if(len <= 0) return;
           _readCallBack(_readBuffer[0..len],_readAddr);
        } catch{
        }
    }

    override void onWrite() nothrow
    {
    }

    override void onClose() nothrow
    {
        if (!isAlive)
            return;
        eventLoop.delEvent(_event);
        _socket.close();
    }
    
private:
    Address _connecto;
    Address _readAddr;
    UdpSocket _socket;
    AsyncEvent* _event;
    ubyte[] _readBuffer;
    UDPReadCallBack _readCallBack;
}