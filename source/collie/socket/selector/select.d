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

module collie.socket.selector.select;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.format;
import std.socket;
import std.experimental.logger;

import collie.socket.common;

class SelectLoop
{
    bool addEvent(AsyncEvent* event) nothrow
    {
        return false;
    }

    bool modEvent(AsyncEvent* event) nothrow
    {
        return false;
    }

    bool delEvent(AsyncEvent* event) nothrow
    {
        return false;
    }

    void weakUp()
    {
        
    }
}

private final class EventChannel : EventCallInterface
{
    this()
    {
        _pair = socketPair();
        _pair[0].blocking = false;
        _pair[1].blocking = false;
        _event = AsyncEvent.create(AsynType.EVENT, this,_pair[1].handle() , true, false, false);
    }
    ~this()
    {
        AsyncEvent.free(_event);
    }

    void doWrite() nothrow
    {
        try{
        _pair[0].send("wekup");
        } catch{}
    }
    override void onRead() nothrow
    {
        ubyte[128] data;
        while(true)
        {
            try{
                if(_pair[1].receive(data) <= 0)
                    return;
            } catch{}
        }
    }

    override void onWrite() nothrow
    {
    }

    override void onClose() nothrow
    {
    }

    Socket[2] _pair;
    AsyncEvent * _event;
}