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

import collie.socket.eventloop;

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
