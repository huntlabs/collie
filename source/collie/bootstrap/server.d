/*
 * Collie - An asynchronous event-driven network framework using Dlang development
 *
 * Copyright (C) 2015-2017  Shanghai Putao Technology Co., Ltd 
 *
 * Developer: putao's Dlang team
 *
 * Licensed under the Apache-2.0 License.
 *
 */
module collie.bootstrap.server;

import kiss.exception;
import kiss.logger;
import kiss.util.timer;

import collie.net;
import collie.channel;
import collie.bootstrap.serversslconfig;
import collie.bootstrap.exception;

import std.exception;

final class ServerBootstrap(PipeLine)
{
    this()
    {
        _loop = new EventLoop();
    }

    this(EventLoop loop)
    {
        _loop = loop;
    }

    auto pipeline(shared AcceptPipelineFactory factory)
    {
        _acceptorPipelineFactory = factory;
        return this;
    }

    auto setSSLConfig(ServerSSLConfig config)
    {
        _sslConfig = config;
        return this;
    }

    auto childPipeline(shared PipelineFactory!PipeLine factory)
    {
        _childPipelineFactory = factory;
        return this;
    }

    auto group(EventLoopGroup group)
    {
        _group = group;
        return this;
    }

    auto setReusePort(bool ruse)
    {
        _rusePort = ruse;
        return this;
    }

    /**
            The Value will be 0 or 5s ~ 1800s.
            0 is disable, 
            if(value < 5) value = 5;
            if(value > 3000) value = 1800;
        */
    auto heartbeatTimeOut(uint second)
    {
        _timeOut = second;
        _timeOut = _timeOut < 5 ? 5 : _timeOut;
        _timeOut = _timeOut > 1800 ? 1800 : _timeOut;

        return this;
    }

    void bind(Address addr)
    {
        _address = addr;
    }

    void bind(ushort port)
    {
        _address = new InternetAddress(port);
    }

    void bind(string ip, ushort port)
    {
        _address = new InternetAddress(ip, port);
    }

    void stopListening()
    {
        if (!_listening)
            return;
        scope (exit)
            _listening = false;
        foreach (ref accept; _serverlist)
        {
            accept.stop();
        }
        _mainAccept.stop();

    }

    void stop()
    {
        if (!_isLoopWait)
            return;
        scope (exit)
            _isLoopWait = false;
        _group.stop();
        _loop.stop();
    }

    void join()
    {
        if (!_isLoopWait)
            return;
        if (_group)
            _group.wait();
    }

    void waitForStop()
    {
		if(_isLoopWait)
			throw new ServerIsRuningException("server is runing!");
		if(!_listening)
			startListening();
		_isLoopWait = true;
		if(_group)
			_group.start();
		_loop.run();
	}

    void startListening()
    {
        if (_listening)
            throw new ServerIsListeningException("server is listening!");
        if (_address is null || _childPipelineFactory is null)
            throw new ServerStartException("the address or childPipelineFactory is null!");

        _listening = true;
        uint wheel, time;
        bool beat = getTimeWheelConfig(wheel, time);
        _mainAccept = creatorAcceptor(_loop);
        _mainAccept.initialize();
        if (beat)
            _mainAccept.startTimingWhile(wheel, time);
        if (_group)
        {
            foreach (loop; _group)
            {
                auto acceptor = creatorAcceptor(loop);
                acceptor.initialize();
                _serverlist ~= acceptor;
                if (beat)
                    acceptor.startTimingWhile(wheel, time);
            }
        }
        logDebug("server _listening!");
    }

    EventLoopGroup group()
    {
        return _group;
    }

    @property EventLoop eventLoop()
    {
        return _loop;
    }

    @property Address address()
    {
        return _address;
    }

protected:
    auto creatorAcceptor(EventLoop loop)
    {
        auto acceptor = new TcpListener(loop, _address.addressFamily);
        if (_rusePort)
            acceptor.reusePort = _rusePort;
        acceptor.bind(_address);
        acceptor.listen(1024);
        {
            Linger optLinger;
            optLinger.on = 1;
            optLinger.time = 0;
            acceptor.setOption(SocketOptionLevel.SOCKET, SocketOption.LINGER, optLinger);
        }
        AcceptPipeline pipe;
        if (_acceptorPipelineFactory)
            pipe = _acceptorPipelineFactory.newPipeline(acceptor);
        else
            pipe = AcceptPipeline.create();

        SSL_CTX* ctx = null;
        version (USE_SSL)
        {
            if (_sslConfig)
            {
                ctx = _sslConfig.generateSSLCtx();
                if (!ctx)
                    throw new SSLException("Can not gengrate SSL_CTX");
            }
        }

        return new ServerAcceptor!(PipeLine)(acceptor, pipe, _childPipelineFactory, ctx);
    }

    bool getTimeWheelConfig(out uint whileSize, out uint time)
    {
        if (_timeOut == 0)
            return false;
        if (_timeOut <= 40)
        {
            whileSize = 50;
            time = _timeOut * 1000 / 50;
        }
        else if (_timeOut <= 120)
        {
            whileSize = 60;
            time = _timeOut * 1000 / 60;
        }
        else if (_timeOut <= 600)
        {
            whileSize = 100;
            time = _timeOut * 1000 / 100;
        }
        else if (_timeOut < 1000)
        {
            whileSize = 150;
            time = _timeOut * 1000 / 150;
        }
        else
        {
            whileSize = 180;
            time = _timeOut * 1000 / 180;
        }
        return true;
    }

private:
    shared AcceptPipelineFactory _acceptorPipelineFactory;
    shared PipelineFactory!PipeLine _childPipelineFactory;

    ServerAcceptor!(PipeLine) _mainAccept;
    EventLoop _loop;

    ServerAcceptor!(PipeLine)[] _serverlist;
    EventLoopGroup _group;

    bool _listening = false;
    bool _rusePort = true;
    bool _isLoopWait = false;
    uint _timeOut = 0;
    Address _address;

    ServerSSLConfig _sslConfig = null;
}

private:

import std.functional;
import kiss.event.timer.common;
import collie.utils.memory;
import collie.net;

final class ServerAcceptor(PipeLine) : InboundHandler!(Socket)
{
    this(TcpListener acceptor, AcceptPipeline pipe,
            shared PipelineFactory!PipeLine clientPipeFactory, SSL_CTX* ctx = null)
    {
        _acceptor = acceptor;
        _pipeFactory = clientPipeFactory;
        pipe.addBack(this);
        pipe.finalize();
        _pipe = pipe;
        _pipe.transport(_acceptor);
        _acceptor.onConnectionAccepted(&acceptCallBack);
        _sslctx = ctx;
        _list = new ServerConnection!PipeLine();
        version (USE_SSL)
            _sharkList = new SSLHandShark();
    }

    void initialize()
    {
        _pipe.transportActive();
    }

    void stop()
    {
        _pipe.transportInactive();
    }

    override void read(Context ctx, Socket msg)
    {
        version (USE_SSL)
        {
            if (_sslctx)
            {
                auto ssl = SSL_new(_sslctx);
                static if (IOMode == IO_MODE.iocp)
                {
                    BIO* readBIO = BIO_new(BIO_s_mem());
                    BIO* writeBIO = BIO_new(BIO_s_mem());
                    SSL_set_bio(ssl, readBIO, writeBIO);
                    SSL_set_accept_state(ssl);
                    auto asynssl = new SSLSocket(_acceptor.eventLoop, msg, ssl, readBIO, writeBIO);
                }
                else
                {
                    if (SSL_set_fd(ssl, msg.handle()) < 0)
                    {
                        error("SSL_set_fd error: fd = ", msg.handle());
                        SSL_shutdown(ssl);
                        SSL_free(ssl);
                        return;
                    }
                    SSL_set_accept_state(ssl);
                    auto asynssl = new SSLSocket(_acceptor.eventLoop, msg, ssl);
                }
                auto shark = new SSLHandShark(asynssl, &doHandShark);

                shark.next = _sharkList.next;
                if (shark.next)
                    shark.next.prev = shark;
                shark.prev = _sharkList;
                _sharkList.next = shark;

                asynssl.start();
            }
            else
            {
                auto asyntcp = new TcpStream(_acceptor.eventLoop, msg);
                startSocket(asyntcp);
            }
        }
        else
        {
            auto asyntcp = new TcpStream(_acceptor.eventLoop, msg);
            startSocket(asyntcp);
        }
    }

    override void transportActive(Context ctx)
    {
        logDebug("acept transportActive");
        try
        {
            _acceptor.start();
        }
        catch (Exception)
        {
            logError("acceptor start error!");
        }
    }

    override void transportInactive(Context ctx)
    {
        _acceptor.close();
        auto con = _list.next;
        _list.next = null;
        while (con)
        {
            auto tcon = con;
            con = con.next;
            tcon.close();
        }
        _acceptor.eventLoop.stop();
    }

protected:
    pragma(inline) void remove(ServerConnection!PipeLine conn)
    {
        conn.prev.next = conn.next;
        if (conn.next)
            conn.next.prev = conn.prev;
        gcFree(conn);
    }

    void acceptCallBack(TcpListener sender, TcpStream stream)
    {
        catchAndLogException(_pipe.read(stream));
    }

    @property acceptor()
    {
        return _acceptor;
    }

    void startTimingWhile(uint whileSize, uint time)
    {
        if (_timer)
            return;
        _timer = new KissTimer(_acceptor.eventLoop, time);
        _timer.onTick(&doWheel);
        _wheel = new TimingWheel(whileSize);
        _timer.start();
    }

    void doWheel(Object)
    {
        if (_wheel)
            _wheel.prevWheel();
    }

    version (USE_SSL)
    {
        void doHandShark(SSLHandShark shark, SSLSocket sock)
        {
            shark.prev.next = shark.next;
            if (shark.next)
                shark.next.prev = shark.prev;
            scope (exit)
                shark.destroy();
            if (sock)
            {
                sock.setHandshakeCallBack(null);
                startSocket(sock);
            }
        }
    }

    void startSocket(TcpStream sock)
    {
        auto pipe = _pipeFactory.newPipeline(sock);
        if (!pipe)
        {
            gcFree(sock);
            return;
        }
        pipe.finalize();
        auto con = new ServerConnection!PipeLine(pipe);
        con.serverAceptor = this;

        con.next = _list.next;
        if (con.next)
            con.next.prev = con;
        con.prev = _list;
        _list.next = con;

        con.initialize();
        if (_wheel)
            _wheel.addNewTimer(con);
    }

private:
    // int[ServerConnection!PipeLine] _list;
    ServerConnection!PipeLine _list;

    version (USE_SSL)
    {
        SSLHandShark _sharkList;
    }

    TcpListener _acceptor;
    KissTimer _timer;
    TimingWheel _wheel;
    AcceptPipeline _pipe;
    shared PipelineFactory!PipeLine _pipeFactory;

    SSL_CTX* _sslctx = null;
}

@trusted final class ServerConnection(PipeLine) : WheelTimer, PipelineManager
{
    this(PipeLine pipe)
    {
        _pipe = pipe;
        _pipe.pipelineManager = this;
    }

    ~this()
    {
    }

    void initialize()
    {
        _pipe.transportActive();
    }

    void close()
    {
        _pipe.transportInactive();
    }

    @property serverAceptor()
    {
        return _manger;
    }

    @property serverAceptor(ServerAcceptor!PipeLine manger)
    {
        _manger = manger;
    }

    override void deletePipeline(PipelineBase pipeline)
    {
        pipeline.pipelineManager = null;
        _pipe = null;
        stop();
        _manger.remove(this);
    }

    override void refreshTimeout()
    {
        rest();
    }

    override void onTimeOut() nothrow
    {
        collectException(_pipe.timeOut());
    }

private:
    this()
    {
    }

    ServerConnection!PipeLine prev;
    ServerConnection!PipeLine next;
    ServerAcceptor!PipeLine _manger;
    PipeLine _pipe;
}

version (USE_SSL)
{
    final class SSLHandShark
    {
        alias SSLHandSharkCallBack = void delegate(SSLHandShark shark, SSLSocket sock);
        this(SSLSocket sock, SSLHandSharkCallBack cback)
        {
            _socket = sock;
            _cback = cback;
            _socket.setCloseCallBack(&onClose);
            _socket.setReadCallBack(&readCallBack);
            _socket.setHandshakeCallBack(&handSharkCallBack);
        }

    protected:
        void handSharkCallBack()
        {
            logDebug("the ssl handshark over");
            _cback(this, _socket);
            _socket = null;
        }

        void readCallBack(ubyte[] buffer)
        {
        }

        void onClose()
        {
            logDebug("the ssl handshark fail");
            _socket.setCloseCallBack(null);
            _socket.setReadCallBack(null);
            _socket.setHandshakeCallBack(null);
            _socket = null;
            _cback(this, _socket);
        }

    private:
        this()
        {
        }

        SSLHandShark prev;
        SSLHandShark next;
        SSLSocket _socket;
        SSLHandSharkCallBack _cback;
    }
}
