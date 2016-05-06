module collie.buffer.buffer;

import core.stdc.string;
import core.memory;

import std.container.array;
import std.string;
import std.experimental.allocator;

interface Buffer
{
    @property bool eof() const;
    size_t read(size_t size, void delegate(in ubyte[]) cback);
    size_t write(in ubyte[] data);
    void rest(size_t size = 0);
    @property size_t length() const;
}

/**
 *  一整块内存的buffer，类本身不管理byte数据的生存周期，只是提供方便的读写接口。
 */
final class PieceBuffer : Buffer
{
    this(ubyte[] buf, size_t writed = 0)
    {
        _data = buf;
        _wSize = writed;
    }

    void clear()
    {
        _rSize = 0;
        _wSize = 0;
    }

    @property bool eof() const
    {
        return (_rSize >= _wSize);
    }

    override @property size_t length() const
    {
        return _wSize;
    }

    override size_t read(size_t size, void delegate(in ubyte[]) cback)
    {
        size_t len = _wSize - _rSize;
        len = size < len ? size : len;
        if (len > 0)
            cback(_data[_rSize .. (_rSize + len)]);
        _rSize += len;
        return len;
    }

    override size_t write(in ubyte[] dt)
    {
        size_t len = _data.length - _wSize;
        len = dt.length < len ? dt.length : len;
        if (len > 0)
        {
            _data[_wSize .. (_wSize + len)] = dt[0 .. len];
        }
        return len;
    }

    ubyte[] data(bool all = false)
    {
        if (all)
        {
            return _data;
        }
        else if (_wSize == 0)
        {
            return null;
        }
        else
        {
            return _data[0 .. _wSize];
        }
    }

    override void rest(size_t size = 0)
    {
        _rSize = size;
    }

private:
    ubyte[] _data;
    size_t _wSize;
    size_t _rSize = 0;
}
