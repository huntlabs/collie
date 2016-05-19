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

    bool connect(Address addr)
    {
        if (isAlive())
            throw new ConnectedException("This Socket is Connected! Please close before connect!");
        if (!start())
            return false;
        _socket.connect(addr);
        return true;
    }

    void setConnectCallBack(ConnectCallBack cback)
    {
        _connectBack = cback;
    }

protected:
    override void onClose()
    {
        if (!_isConnect && _connectBack)
        {
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
        if (!_isConnect && _connectBack)
        {
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
    ConnectCallBack _connectBack;
}

class ConnectedException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}
