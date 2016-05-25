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
module collie.socket.tcpclient;

import std.socket;

import collie.socket.eventloop;
import collie.socket.common;
import collie.socket.tcpsocket;

alias ConnectCallBack = void delegate(bool connect);

final class TCPClient : TCPSocket
{
    this(EventLoop loop, bool isIpV6 = false)
    {
        super(loop, isIpV6);
    }

    override @property bool isAlive() @trusted nothrow
    {
        return super.isAlive() && _isConnect;
    }

    pragma(inline)
    bool connect(Address addr)
    {
        if (isAlive())
            throw new ConnectedException("This Socket is Connected! Please close before connect!");
        if (!start())
            return false;
        _isFrist = true;
        _socket.connect(addr);
        return true;
    }
    
    pragma(inline)
    void setConnectCallBack(ConnectCallBack cback)
    {
        _connectBack = cback;
    }

protected:
    override void onClose()
    {
        if (_isFrist && !_isConnect && _connectBack)
        {
            _isFrist = false;
            try
            {
                _connectBack(false);
            }
            catch
            {
            }
            return;
        }
        super.onClose();
        _isConnect = false;
    }

    override void onWrite()
    {
        if (_isFrist && !_isConnect && _connectBack)
        {
            _isFrist = false;
            try
            {
                _connectBack(true);
            }
            catch
            {
            }
            _isConnect = true;
        }

        super.onWrite();
    }

private:
    bool _isConnect = false;
    bool _isFrist = true;;
    ConnectCallBack _connectBack;
}

class ConnectedException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}
