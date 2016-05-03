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

    @property bool isConnect()
    {
        return _isConnect;
    }

    bool connect(Address addr)
    {
        if (_isConnect)
            close();
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
            } catch {}
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
            } catch {}
        }

        super.onWrite();
    }

private:
    bool _isConnect = false;
    ConnectCallBack _connectBack;
}
