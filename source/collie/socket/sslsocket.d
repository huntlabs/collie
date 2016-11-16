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
module collie.socket.sslsocket;

import core.stdc.errno;
import core.stdc.string;

import std.socket;
import std.exception;

import collie.socket.eventloop;
import collie.socket.common;
import collie.socket.transport;
import collie.socket.tcpsocket;

static if(USEDSSL)
{

    import deimos.openssl.ssl;
import std.string;

    class SSLSocket : TCPSocket
    {
        this(EventLoop loop, Socket sock, SSL* ssl)
        {
            super(loop, sock);
            _ssl = ssl;
        }

        ~this()
        {
            if (_ssl)
            {
                SSL_shutdown(_ssl);
                SSL_free(_ssl);
                _ssl = null;
            }
        }

        override @property bool isAlive() @trusted nothrow
        {
            return alive() && _isHandshaked;
        }

        pragma(inline) void setHandshakeCallBack(CallBack cback)
        {
            _handshakeCback = cback;
        }

    protected:
        override void onClose()
        {
			if (_ssl)
			{
				SSL_shutdown(_ssl);
				SSL_free(_ssl);
				_ssl = null;
			}
            super.onClose();
        }

        override void onWrite()
        {
            if (!alive)
                return;
            if (!_isHandshaked)
            {
                if (!handlshake())
                    return;
            }
            while (!_writeQueue.empty)
            {
                try
                {
                    auto buffer = _writeQueue.front;
                    auto len = SSL_write(_ssl, buffer.data.ptr, cast(int) buffer.length); // _socket.send(buffer.data);
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
					import collie.utils.exception;
					showException(e);
                    onClose();
                }
            }
        }

        override void onRead()
        {
            if (!alive)
                return;
            if (!_isHandshaked)
            {
                if (!handlshake())
                    return;
            }
            while (true)
            {
                try
                {
                    auto len = SSL_read(_ssl, (_readBuffer.ptr), cast(int)(_readBuffer.length));
                    if (len > 0)
                    {
                        collectException(_readCallBack(_readBuffer[0 .. len]));
                    }
                    else
                    {
                        int sslerron = SSL_get_error(_ssl, len);
                        if (sslerron == SSL_ERROR_WANT_READ || errno == EWOULDBLOCK
                                || errno == EAGAIN)
                            break;
                        else if (errno == 4) // erro 4 :系统中断组织了
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
					import collie.utils.exception;
					showException(e);
                    onClose();
                }
            }
        }

        final bool handlshake() nothrow
        {
            int r = SSL_do_handshake(_ssl);
            if (r == 1)
            {
				//collectException(trace("ssl connected fd : ", fd));
                _isHandshaked = true;
                if (_handshakeCback)
                {
                    collectException(_handshakeCback());
                }
                return true;
            }
            int err = SSL_get_error(_ssl, r);
            if (err == SSL_ERROR_WANT_WRITE)
            {
				//collectException(trace("return want write fd = ", fd));
                return false;
            }
            else if (err == SSL_ERROR_WANT_READ)
            {
				//collectException(trace("return want read fd = ", fd));
                return false;
            }
            else
            {
				collectException(trace("SSL_do_handshake return: ", r, "  erro :", err,
                    "  errno:", errno, "  erro string:", fromStringz(strerror(errno))));
                onClose();
                return false;
            }
        }

    protected:
        bool _isHandshaked = false;

    private:
        SSL* _ssl;
        CallBack _handshakeCback;
    }
}
