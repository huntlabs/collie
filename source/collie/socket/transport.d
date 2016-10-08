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
module collie.socket.transport;

import collie.socket.common;
import collie.socket.eventloop;

enum TransportType : short
{
    ACCEPT,
    TCP,
    UDP
}

__gshared size_t TCP_READ_BUFFER_SIZE = 16 * 1024;
__gshared size_t  UDP_READ_BUFFER_SIZE = 16 * 1024;



abstract class AsyncTransport
{
    this(EventLoop loop, TransportType type)
    {
        _loop = loop;
    }

    void close();
    bool start();
    @property bool isAlive() @trusted;
    @property int fd();

    final @property transportType()
    {
        return _type;
    }

    final @property eventLoop()
    {
        return _loop;
    }
protected:
    EventLoop _loop;
    TransportType _type;
}

static if (IOMode == IO_MODE.epoll)
{
    version (X86)
    {

        enum SO_REUSEPORT = 15;
    }
    else version (X86_64)
    {
        enum SO_REUSEPORT = 15;
    }
    else version (MIPS32)
    {
        enum SO_REUSEPORT = 0x0200;

    }
    else version (MIPS64)
    {
        enum SO_REUSEPORT = 0x0200;
    }
    else version (PPC)
    {
        enum SO_REUSEPORT = 15;
    }
    else version (PPC64)
    {
        enum SO_REUSEPORT = 15;
    }
    else version (ARM)
    {
        enum SO_REUSEPORT = 15;
    }
}
else static if (IOMode == IO_MODE.kqueue)
{
    enum SO_REUSEPORT = 0x0200;
}

mixin template TransportSocketOption()
{
    import std.functional;
    import std.datetime;
    import core.stdc.stdint;

    /// Get a socket option.
    /// Returns: The number of bytes written to $(D result).
    //returns the length, in bytes, of the actual result - very different from getsockopt()
    pragma(inline) final int getOption(SocketOptionLevel level,
        SocketOption option, void[] result) @trusted
    {

        return _socket.getOption(level, option, result);
    }

    /// Common case of getting integer and boolean options.
    pragma(inline) final int getOption(SocketOptionLevel level,
        SocketOption option, ref int32_t result) @trusted
    {
        return _socket.getOption(level, option, result);
    }

    /// Get the linger option.
    pragma(inline) final int getOption(SocketOptionLevel level,
        SocketOption option, ref Linger result) @trusted
    {
        return _socket.getOption(level, option, result);
    }

    /// Get a timeout (duration) option.
    pragma(inline) final void getOption(SocketOptionLevel level,
        SocketOption option, ref Duration result) @trusted
    {
        _socket.getOption(level, option, result);
    }

    /// Set a socket option.
    pragma(inline) final void setOption(SocketOptionLevel level,
        SocketOption option, void[] value) @trusted
    {
        return _socket.setOption(forward!(level, option, value));
    }

    /// Common case for setting integer and boolean options.
    pragma(inline) final void setOption(SocketOptionLevel level,
        SocketOption option, int32_t value) @trusted
    {
        return _socket.setOption(forward!(level, option, value));
    }

    /// Set the linger option.
    pragma(inline) final void setOption(SocketOptionLevel level,
        SocketOption option, Linger value) @trusted
    {
        return _socket.setOption(forward!(level, option, value));
    }

    pragma(inline) final void setOption(SocketOptionLevel level,
        SocketOption option, Duration value) @trusted
    {
        return _socket.setOption(forward!(level, option, value));
    }

    pragma(inline) final @property @trusted Address localAddress()
    {
        return _socket.localAddress();
    }
}
