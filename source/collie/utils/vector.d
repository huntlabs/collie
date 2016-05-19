module collie.utils.vector;

import core.memory;
import std.experimental.allocator.common;
import std.experimental.allocator.mallocator : AlignedMallocator;
import std.traits;

struct Vector(T, bool addToGC = hasIndirections!T, Allocator = AlignedMallocator)
{
    this(size_t size)
    {
        auto len = T.sizeof * size;
        _data = cast(T[]) _alloc.allocate(len);
        static if (addToGC)
        {
            GC.addRange(_data.ptr, len);
        }
    }

    this(T[] data)
    {
        this(data.length);
        _data[] = data[];
        _len = data.length;
    }

    static if (stateSize!Allocator != 0)
    {
        this(T[] data, Allocator alloc)
        {
            this._alloc = alloc;
            this(data);
        }

        this(size_t size, Allocator alloc)
        {
            this._alloc = alloc;
            this(size);
        }

    }

    ~this()
    {

        static if (addToGC)
        {
            GC.removeRange(_data.ptr);
        }
        if (_data.ptr)
            _alloc.deallocate(_data);
    }

    pragma(inline)
    void insertBack(T value)
    {
        if (full)
            exten(1);
        _data[_len] = value;
        ++_len;
    }

    pragma(inline)
    void insertBack(T[] value)
    {
        if (_data.length < (_len + value.length))
            exten(value.length);
        auto len = _len + value.length;
        _data[_len .. len] = value[];
        _len = len;
    }

    void insertBefore(T value)
    {
        if (full)
            exten(1);
        if (empty())
        {
            _data[0] = value;
            _len = 1;
            return;
        }
        T tm = _data[0];
        _data[0] = value;
        import std.algorithm.mutation : move;

        foreach (i; 1 .. _len)
        {
            auto tmp = _data[i];
            _data[i] = tm;
            tm = move(tmp);
        }
        _data[_len] = tm;
        ++_len;
    }

    size_t removeBack(size_t howMany = 1)
    {
        if (howMany >= _len)
        {
            clear();
            return _len;
        }
        auto size = _len - howMany;
        _data[size .. _len] = T.init;
        _len = size;
        return howMany;
    }

    void removeSite(size_t site)
    {
        assert(site < _len);
        --_len;
        for (size_t i = site; i < _len; ++i)
        {
            _data[i] = _data[i + 1];
        }
        _data[_len] = T.init;
    }

    void removeOne(T value)
    {
        for (size_t i = 0; i < _len; ++i)
        {
            if (_data[i] == value)
            {
                removeSite(i);
                return;
            }
        }
    }

    void removeAny(T value)
    {
        for (size_t i = 0; i < _len; ++i)
        {
            if (_data[i] == value)
            {
                removeSite(i);
                return;
            }
        }
    }

    pragma(inline)
    @property T[] dup()
    {
        auto list = new T[length];
        list[0 .. length] = _data[0 .. length];
        return list;
    }

    pragma(inline)
    inout ref inout(T) opIndex(size_t i)
    {
        assert(i < _len);
        return _data[i];
    }

    pragma(inline,true)
    T at(size_t i)
    {
        assert(i < _len);
        return _data[i];
    }

    pragma(inline,true)
    const @property bool empty()
    {
        return (_len == 0);
    }

    pragma(inline,true)
    const @property size_t length()
    {
        return _len;
    }

    pragma(inline,true)
    void clear()
    {
        _data[] = T.init;
        _len = 0;
    }

private:
    bool full()
    {
        return length == _data.length;
    }

    void exten(size_t len)
    {
        auto size = _data.length;
        if (size > 0)
            size = size > 128 ? size + ((size / 3) * 2) : size * 2;
        else
            size = 32;
        size += len;
        len = T.sizeof * size;
        auto data = cast(T[]) _alloc.allocate(T.sizeof * size);
        if (!empty)
        {
            data[0 .. length] = _data[0 .. length];
        }
        static if (addToGC)
        {
            GC.addRange(data.ptr, len);
            GC.removeRange(_data.ptr);
        }
        _alloc.deallocate(_data);
        _data = data;
    }

private:
    size_t _len = 0;
    T[] _data = null;
    static if (stateSize!Allocator == 0)
        alias _alloc = Allocator.instance;
    else
        Allocator _alloc;
}

unittest
{
    import std.stdio;

    Vector!(int) vec; // = Vector!int(5);
    int[] aa = [0, 1, 2, 3, 4, 5, 6, 7];
    vec.insertBack(aa);
    assert(vec.length == 8);

    vec.insertBack(10);
    assert(vec.length == 9);

    vec.insertBefore(15);
    assert(vec.length == 10);

    assert(vec.dup == [15, 0, 1, 2, 3, 4, 5, 6, 7, 10]);

    vec[1] = 500;

    assert(vec.dup == [15, 500, 1, 2, 3, 4, 5, 6, 7, 10]);

    vec.removeBack();
    assert(vec.length == 9);
    assert(vec.dup == [15, 500, 1, 2, 3, 4, 5, 6, 7]);

    vec.removeBack(3);
    assert(vec.length == 6);
    assert(vec.dup == [15, 500, 1, 2, 3, 4]);

    vec.insertBack(aa);
    assert(vec.dup == [15, 500, 1, 2, 3, 4, 0, 1, 2, 3, 4, 5, 6, 7]);

    vec.removeSite(1);
    assert(vec.dup == [15, 1, 2, 3, 4, 0, 1, 2, 3, 4, 5, 6, 7]);

    vec.removeOne(1);
    assert(vec.dup == [15, 2, 3, 4, 0, 1, 2, 3, 4, 5, 6, 7]);

    vec.removeAny(2);
    assert(vec.dup == [15, 3, 4, 0, 1, 2, 3, 4, 5, 6, 7]);
}
