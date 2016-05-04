module collie.socket.sslsocket;

import core.stdc.errno;
import core.stdc.string;

import std.socket;

import collie.socket.eventloop;
import collie.socket.common;
import collie.socket.tcpsocket;

import deimos.openssl.ssl;

//TODO: Need Test
class SSLSocket : TCPSocket
{
    this(EventLoop loop, Socket sock,SSL * ssl)
    {
        super(loop, sock);
    }
    
    ~this()
    {
        if(_ssl){
            SSL_shutdown (_ssl);
            SSL_free(_ssl);
            _ssl = null;
        }
    }
    
    
    override @property bool isAlive() @trusted nothrow
    {
        return super.isAlive() && _isHandshaked;
    }

    void setHandshakeCallBack(CallBack cback)
    {
        _handshakeCback = cback;
    }
    
protected:
    override void onClose()
    {
        super.onClose();
        if(_ssl)
        {
            SSL_shutdown (_ssl);
            SSL_free(_ssl);
            _ssl = null;
        }
    }

    override void onWrite()
    {
        if(!_isHandshaked)
        {
            if(!handlshake()) return;
        }
        while (isAlive && !_writeQueue.empty)
        {
            try
            {
                auto buffer = _writeQueue.front;
                auto len = SSL_write(_ssl,buffer.data.ptr,cast(int)buffer.length);// _socket.send(buffer.data);
                if (len > 0)
                {
                    if (buffer.add(len))
                    {
                        _writeQueue.deQueue().doCallBack();
                    }
                }
                else if (errno == EWOULDBLOCK || errno == EAGAIN)
                {
                    break;
                }
                else if (errno == 4)
                {
                    continue;
                }
                else
                {
                    trace(" write Erro Do Close erro = ", _socket.ERROR);
                    onClose();
                    return;
                }
            }
            catch (Exception e)
            {
                try
                {
                    error("\n\n----tcp on Write erro do Close! erro : ", e.msg, "\n\n");
                }
                catch
                {
                }
                onClose();
            }
        }
    }

    override void onRead()
    {
        if(!_isHandshaked)
        {
            if(!handlshake()) return;
        }
        while (isAlive)
        {
            try
            {
                auto len = SSL_read(_ssl,(_readBuffer.allData.ptr),cast(int)(_readBuffer.maxLength));
                if (len > 0)
                {
                    _readBuffer.setLength(len);
                    _readCallBack(_readBuffer);
                    _readBuffer = new UniqueBuffer(TCP_READ_BUFFER_SIZE);
                } 
                else
                {
                    int sslerron = SSL_get_error(_ssl, len);
                    if (sslerron == SSL_ERROR_WANT_READ || errno == EWOULDBLOCK || errno == EAGAIN )
                        break;
                    else if(errno == 4) // erro 4 :系统中断组织了
                        continue;
                    else
                    {
                        trace("read Erro Do Close the erro : ", _socket.ERROR);
                        onClose();
                        return;
                    }
                }
            }
            catch (Exception e)
            {
                try
                {
                    error("\n\n----tcp on read erro do Close! erro : ", e.msg, "\n\n");
                }
                catch
                {
                }
                onClose();
            }
        }
    }

    final bool handlshake() nothrow
    {
        int r = SSL_do_handshake(_ssl);
        if (r == 1) 
        {
            try{trace("ssl connected fd : ", fd);}catch{}
            _isHandshaked = true;
            if(_handshakeCback)
            {
                try
                {
                    _handshakeCback();
                }
                catch
                {
                    onClose();
                    return false;
                }
            }
            return true;
        }
        int err = SSL_get_error(_ssl, r);
        if (err == SSL_ERROR_WANT_WRITE) 
        {
            try{trace("return want write fd = ", fd);}catch{}
            return false;
        } 
        else if (err == SSL_ERROR_WANT_READ) 
        {
            try{trace("return want read fd = ", fd);}catch{}
            return false;
        }
        else 
        {
            try{trace("SSL_do_handshake return: ", r,"  erro :" , err,"  errno:", errno, "  erro string:",strerror(errno));}catch{}
            onClose();
            return false;
        } 
    }
protected:
    bool _isHandshaked = false;
    
private:
    SSL * _ssl;
    CallBack _handshakeCback;
}
