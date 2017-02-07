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
module collie.utils.vector;

import core.memory;
import std.exception;
import std.experimental.allocator.common;
import std.experimental.allocator.gc_allocator;
import collie.utils.allocator;
import std.traits;
import core.stdc.string :  memset, memcpy;

@trusted struct Vector(T, TAllocator = T, bool addInGC = true)
{
	static if(hasMember!(TAllocator,"allocate") && hasMember!(TAllocator,"deallocate") ){
		alias Allocator = TAllocator;
		enum addToGC = addInGC && hasIndirections!T && !is(Allocator == GCAllocator);
	} else {
		version(OSX) {
			alias Allocator = GCAllocator;
		} else {
			alias Allocator = CollieAllocator!(T[],(hasIndirections!T));
		}
		enum addToGC = false;
	}
	
	static if(hasIndirections!T)
		alias InsertT = T;
	else
		alias InsertT = const T;

    static if (stateSize!Allocator != 0)
    {
        this() @disable;
		this(T[] data, Allocator alloc,bool copy = true)
        {
            this._alloc = alloc;
            _len = data.length;
            if(copy) {
                reserve(data.length);
                _data[0.._len] = data[];
            } else {
                _data = data;
            }
        }

        this(size_t size, Allocator alloc)
        {
            this._alloc = alloc;
            reserve(size);
        }

        this(Allocator alloc){
            this._alloc = alloc;
        }

		@property allocator(){return _alloc;}

    } else {
        this(size_t size) 
        {
            reserve(size);
        }

        this(ref T[] data, bool copy = true)
        {
            _len = data.length;
            if(copy) {
                reserve(data.length);
                _data[0.._len] = data[];
            } else {
                _data = data;
            }
        }
    }

    ~this()
    {
        if (_data.ptr)
        {
            if(_len > 0)
                _data[0.._len] = T.init;
            static if (addToGC)
                GC.removeRange(_data.ptr);
            _alloc.deallocate(_data);
			_data = null;
        }
    }

	pragma(inline) void insertBack(InsertT value)
    {
        if (full)
            exten();
        _data[_len] = value;
        ++_len;
    }

	pragma(inline) void insertBack(InsertT[] value)
    {
        if (_data.length < (_len + value.length))
            exten(value.length);
        auto len = _len + value.length;
        _data[_len .. len] = value[];
        _len = len;
    }

	alias put = insertBack;
	alias pushBack = insertBack;

	void insertBefore(InsertT value)
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

	alias removeIndex = removeSite;

	void removeOne(InsertT value)
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

	void removeAny(InsertT value)
    {
        auto len = _len;
        size_t rm = 0;
        size_t site  = 0;
        for (size_t j = site; j < len; ++j)
        {
                if(_data[j] != value) {
                        _data[site] = _data[j];
                        site ++;
                } else {
                        rm ++;
                }
        }
        len -= rm;
        _data[len.._len] = T.init;
        _len = len;
    }

	pragma(inline) @property ptr(){
		return _data.ptr;
	}

    pragma(inline) @property T[] dup()  
    {
        auto list = new T[length];
        list[0 .. length] = _data[0 .. length];
        return list;
    }

    pragma(inline) T[] data(bool rest = true)
    {
        auto list = _data[0 .. length];
        if (rest)
        {
            _data = null;
            _len = 0;
        }
        return list;
    }

	pragma(inline) ref inout(T) opIndex(size_t i) inout
    {
        assert(i < _len);
        return _data[i];
    }

	pragma(inline) size_t opDollar() const { return _len;}

	pragma(inline) void opOpAssign(string op)(InsertT value) if(op == "~")
	{
		insertBack(value);
	}

	pragma(inline) void opOpAssign(string op)(InsertT[] value) if(op == "~")
	{
		insertBack(value);
	}

	pragma(inline) void opAssign(ref typeof(this) s)
	{
		this._len = s._len;
        if(_len > 0) {
            this.reserve(_len);
            memcpy(this._data.ptr, s._data.ptr, (_len * T.sizeof));
		}
        static if (stateSize!Allocator != 0)
            this._alloc = s._alloc;
	}

	pragma(inline) void opAssign(T[] data)
	{
		this._len = data.length;
		if(_len > 0) {
            this.reserve(_len);
             memcpy(this._data.ptr, data.ptr, (_len * T.sizeof));
		}
	}

    pragma(inline, true) T at(size_t i) 
    {
        assert(i < _len);
        return _data[i];
    }

    pragma(inline, true) const @property bool empty()
    {
        return (_len == 0);
    }

    pragma(inline, true) const @property size_t length()
    {
        return _len;
    }

    pragma(inline, true) void clear()
    {
        _data[] = T.init;
        _len = 0;
    }

	void reserve(size_t elements)
	{
		if(elements <= _data.length) return;
		size_t len = elements * T.sizeof;
		static if(hasMember!(Allocator,"goodAllocSize")){
			len = _alloc.goodAllocSize(len);
			elements = len / T.sizeof;
		}
        auto ptr = cast(T *) enforce(_alloc.allocate(len).ptr);
        T[] data = ptr[0..elements];
        memset(ptr,0,len);
        if(_len > 0) {
            memcpy(ptr, _data.ptr, (_len * T.sizeof));
        }
        static if (addToGC) {
            GC.addRange(ptr, len);
            if(_data.ptr) {
                GC.removeRange(_data.ptr);
                _alloc.deallocate(_data);
            }
        } else {
            if(_data.ptr) {
                _alloc.deallocate(_data);
            }
        } 
        _data = data;
	}
private:
    pragma(inline, true) 
    bool full()
    {
        return length >= _data.length;
    }

	pragma(inline) 
    void exten(size_t len = 0)
    {
        auto size = _data.length + len;
        if (size > 0)
            size = size > 128 ? size + ((size / 3) * 2) : size * 2;
        else
            size = 32;
		reserve(size);
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
	import std.experimental.allocator.mallocator;
    import std.experimental.allocator;

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
    assert(vec.dup == [15, 3, 4, 0, 1, 3, 4, 5, 6, 7]);
    
    Vector!(ubyte[],Mallocator) vec2;
    vec2.insertBack(cast(ubyte[])"hahaha");
    vec2.insertBack(cast(ubyte[])"huhuhu");
    assert(vec2.length == 2);
    assert(cast(string)vec2[0] == "hahaha");
    assert(cast(string)vec2[1] == "huhuhu");

    Vector!(int,IAllocator) vec22 = Vector!(int,IAllocator)(processAllocator);
    int[] aa22 = [0, 1, 2, 3, 4, 5, 6, 7];
    vec22.insertBack(aa22);
    assert(vec22.length == 8);

    vec22.insertBack(10);
    assert(vec22.length == 9);

    vec22.insertBefore(15);
    assert(vec22.length == 10);
}
