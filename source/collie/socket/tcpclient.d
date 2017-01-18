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
import std.exception;

import collie.socket.eventloop;
import collie.socket.common;
import collie.socket.tcpsocket;
import collie.socket.exception;
import collie.utils.exception;

alias ConnectCallBack = void delegate(bool connect);

@trusted final class TCPClient : TCPSocket
{
    this(EventLoop loop, bool isIpV6 = false)
    {
        super(loop, isIpV6);
    }

	this(EventLoop loop, AddressFamily family)
	{
		super(loop,family);
	}

    override @property bool isAlive() @trusted nothrow
    {
        return super.isAlive() && _isConnect;
    }

    pragma(inline) bool connect(Address addr)
    {
        if (isAlive())
            throw new ConnectedException("This Socket is Connected! Please close before connect!");
        static if (IOMode == IO_MODE.iocp)
        {
            Address bindddr;
            if (addr.addressFamily() == AddressFamily.INET)
            {
                bindddr = new InternetAddress(InternetAddress.PORT_ANY);
            }
            else if (addr.addressFamily() == AddressFamily.INET6)
            {
                bindddr = new Internet6Address(Internet6Address.PORT_ANY);
            }
            else
                throw new ConnectedException("This Address is not a network address!");
            _socket.bind(bindddr);
            _loop.addEvent(_event);
            _iocpread.event = _event;
            _iocpread.operationType = IOCP_OP_TYPE.connect;
            int b = ConnectEx(cast(SOCKET) _socket.handle,
                cast(SOCKADDR*) addr.name(), addr.nameLen(), null, 0, null, &_iocpread.ol);
            if (b == 0)
            {
                DWORD dwLastError = GetLastError();
                if (dwLastError != ERROR_IO_PENDING)
                {
                    error("ConnectEx failed with error: ", dwLastError);
                    return false;
                }
            }
            return true;
        }
        else
        {
            if (!start())
                return false;
            _isFrist = true;
            _socket.connect(addr);
            return true;
        }
    }

    pragma(inline) void setConnectCallBack(ConnectCallBack cback)
    {
        _connectBack = cback;
    }

protected:
    override void onClose()
    {
		//collectException(trace("onclose!!"));
        if (_isFrist && !_isConnect && _connectBack)
        {
            _isFrist = false;
			collieCathException!false(_connectBack(false));
            return;
        }
		_isConnect = false;
        super.onClose();
    }

    override void onWrite()
    {
		//collectException(trace("onWrite!!"));
        if (_isFrist && !_isConnect && _connectBack)
        {
            _isFrist = false;
			_isConnect = true;
			collieCathException!false(_connectBack(true));
        }

        super.onWrite();
    }

private:
    bool _isConnect = false;
    bool _isFrist = true;
    ConnectCallBack _connectBack;
}


