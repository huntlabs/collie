module collie.socket.tcpsocket;

import core.memory;
import core.stdc.errno;

import std.socket;
import std.experimental.allocator.gc_allocator;

import collie.socket.common;
import collie.socket.eventloop;
import collie.utils.queue;
import collie.utils.functional;
public import collie.buffer.uniquebuffer;

alias TCPWriteCallBack = void delegate(ubyte[] data, uint writeSzie);
alias TCPReadCallBack = void delegate(UniqueBuffer buffer);

class TCPSocket : AsyncTransport, EventCallInterface
{
    this(EventLoop loop, bool isIpV6 = false)
    {
        if (isIpV6)
            _socket = new Socket(AddressFamily.INET6, SocketType.STREAM, ProtocolType.TCP);
        else
            _socket = new Socket(AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
        this(loop, _socket);
    }

    this(EventLoop loop, Socket sock)
    {
        super(loop);
        _socket = sock;
        _socket.blocking = false;
        _writeQueue = Queue!(WriteSite, true, false, GCAllocator)(32);
        _readBuffer = new UniqueBuffer(TCP_READ_BUFFER_SIZE);
        _event = AsyncEvent.create(AsynType.TCP, this, _socket.handle, true, true, true);
    }

    ~this()
    {
        if (_event.isActive)
        {
            eventLoop.delEvent(_event);
        }
        if (_socket.isAlive())
            _socket.close();
        AsyncEvent.free(_event);
    }

    //	@property Socket socket(){return _socket;}

    final override @property int fd()
    {
        return cast(int) _socket.handle();
    }

    override bool start()
    {
        if (_event.isActive || !_socket.isAlive() || !_readCallBack)
            return false;
        _event.fd = _socket.handle();
        _loop.addEvent(_event);
        return true;
    }

    final override void close()
    {
        trace("Close the socket!");
        if (isAlive)
        {
            eventLoop.post(bind(&onClose));
        }
        else if (_socket.isAlive())
        {
            //Linger optLinger;
            //_socket.setOption(SocketOptionLevel.SOCKET,SocketOption.LINGER,
            _socket.close();
        }
    }

    override @property bool isAlive() @trusted nothrow
    {
        try
        {
            return _event.isActive && _socket.isAlive();
        }
        catch
        {
            return false;
        }
    }

    void write(ubyte[] data, TCPWriteCallBack cback)
    {
        if (!isAlive)
        {
            cback(data, 0);
            return;
        }
        eventLoop.post(bind!(void delegate(WriteSite))(&doWrite, new WriteSite(data,
            cback))); //利用eventloop的post处理跨线程问题
    }

    mixin TCPSocketOption;

    void setKeepAlive(int time, int interval) @trusted
    {
        return _socket.setKeepAlive(forward!(time, interval));
    }

    @property @trusted Address remoteAddress()
    {
        return _socket.remoteAddress();
    }

    final void setReadCallBack(TCPReadCallBack cback)
    {
        _readCallBack = cback;
    }

    final void setCloseCallBack(CallBack cback)
    {
        _unActive = cback;
    }

protected:
    /**
	 * 放入队列里的写。
	 */
    void doWrite(WriteSite buffer)
    {
        if (!isAlive || !_writeQueue.enQueue(buffer))
        {
            buffer.doCallBack();
        }
        onWrite();
    }

    override void onWrite() nothrow
    {
        while (isAlive && !_writeQueue.empty)
        {
            try
            {
                auto buffer = _writeQueue.front;
                auto len = _socket.send(buffer.data);
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

    override void onClose() nothrow
    {
        if (!isAlive)
            return;
        eventLoop.delEvent(_event);
        //	delete _event;
        while (!_writeQueue.empty)
        {
            _writeQueue.deQueue().doCallBack();
        }
        try
        {
            _socket.close();
            scope (exit)
            {
                _readCallBack = null;
                _unActive = null;
            }
            if (_unActive)
                _unActive();
        }
        catch (Exception e)
        {
            try
            {
                error("\n\n----Close  Handle erro : ", e.msg, "\n\n");
            }
            catch
            {
            }
        }
    }

    override void onRead() nothrow
    {
        try{trace("onread  tecp ");}catch{}
        while (isAlive)
        {
            try
            {
                auto len = _socket.receive(_readBuffer.allData);
                if (len > 0)
                {
                    _readBuffer.setLength(len);
                    _readCallBack(_readBuffer);
                    _readBuffer = new UniqueBuffer(TCP_READ_BUFFER_SIZE);
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
                    trace("read Erro Do Close the erro : ", _socket.ERROR);
                    onClose();
                    return;
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

protected:
    Socket _socket;
    Queue!(WriteSite, true, false, GCAllocator) _writeQueue;
    AsyncEvent* _event;

    UniqueBuffer _readBuffer;

    CallBack _unActive;
    TCPReadCallBack _readCallBack;
}

mixin template TCPSocketOption()
{
    import std.functional;
    import std.datetime;
    import core.stdc.stdint;

    /// Get a socket option.
    /// Returns: The number of bytes written to $(D result).
    //returns the length, in bytes, of the actual result - very different from getsockopt()
    int getOption(SocketOptionLevel level, SocketOption option, void[] result) @trusted
    {

        return _socket.getOption(level, option, result);
    }

    /// Common case of getting integer and boolean options.
    int getOption(SocketOptionLevel level, SocketOption option, ref int32_t result) @trusted
    {
        return _socket.getOption(level, option, result);
    }

    /// Get the linger option.
    int getOption(SocketOptionLevel level, SocketOption option, ref Linger result) @trusted
    {
        return _socket.getOption(level, option, result);
    }

    /// Get a timeout (duration) option.
    void getOption(SocketOptionLevel level, SocketOption option, ref Duration result) @trusted
    {
        _socket.getOption(level, option, result);
    }

    /// Set a socket option.
    void setOption(SocketOptionLevel level, SocketOption option, void[] value) @trusted
    {
        return _socket.setOption(forward!(level, option, value));
    }

    /// Common case for setting integer and boolean options.
    void setOption(SocketOptionLevel level, SocketOption option, int32_t value) @trusted
    {
        return _socket.setOption(forward!(level, option, value));
    }

    /// Set the linger option.
    void setOption(SocketOptionLevel level, SocketOption option, Linger value) @trusted
    {
        return _socket.setOption(forward!(level, option, value));
    }

    void setOption(SocketOptionLevel level, SocketOption option, Duration value) @trusted
    {
        return _socket.setOption(forward!(level, option, value));
    }

    @property @trusted Address localAddress()
    {
        return _socket.localAddress();
    }
}

package:
final class WriteSite
{
    this(ubyte[] data, TCPWriteCallBack cback = null)
    {
        _data = data;
        _site = 0;
        _cback = cback;
    }

    bool add(size_t size) //如果写完了就返回true。
    {
        _site += size;
        if (_site >= _data.length)
            return true;
        else
            return false;
    }

    @property size_t length() const
    {
        return (_data.length - _site);
    }

    @property data()
    {
        return _data[_site .. $];
    }

    void doCallBack() nothrow
    {

        if (_cback)
        {
            try
            {
                _cback(_data, cast(uint) _site);
            }
            catch (Exception e)
            {
                try
                {
                    error("\n\n----Write Call Back Erro ! erro : ", e.msg, "\n\n");
                }
                catch
                {
                }
            }
        }
        _cback = null;
        _data = null;
    }

private:
    size_t _site = 0;
    ubyte[] _data;
    TCPWriteCallBack _cback;
}
