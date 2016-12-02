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
module collie.utils.queue;

import core.memory;
import std.experimental.allocator.common;
import std.experimental.allocator.mallocator : Mallocator;
import std.experimental.allocator.gc_allocator;
import std.traits;
import collie.utils.allocator;

/**
    Queue Struct Template.
    Params:
        T         = the element type;
        autoExten = if the Queue is full, will or not auto expand;
        addToGC   = if use other Allocator, will or not add to GC scan.
        Allocator = which type Allocator will used
*/

@trusted struct Queue(T,  Allocator = CollieAllocator!T, bool autoExten = false, bool addInGC = true)
{
    enum TSize = T.sizeof;
	enum addToGC = addInGC && hasIndirections!T && !is(Allocator == GCAllocator) && !is(Allocator == CollieAllocator!T);
	static if(hasIndirections!T)
		alias InsertT = T;
	else
		alias InsertT = const T;

    /**
        Params:
            size        =  the queue init size. 
    */
    this(uint size)
    {
        assert(size > 3);
        _size = size;
        _data = cast(T[]) _alloc.allocate(TSize * size);
        static if (addToGC && !is(Allocator == GCAllocator))
        {
            GC.addRange(_data.ptr, len);
        }
    }

    static if (stateSize!Allocator != 0)
    {
        this(uint size, Allocator alloc)
        {
            this._alloc = alloc;
            this(size);
        }
    }
    ~this()
    {
        //clear();
        static if (addToGC && !is(Allocator == GCAllocator))
        {
            GC.removeRange(_data.ptr);
        }
        if (_data.ptr)
            _alloc.deallocate(_data);
    }

    pragma(inline, true) void clear()
    {

        _data[] = T.init;
        _front = _rear = 0;
    }

    pragma(inline, true) @property bool empty() const nothrow
    {
		return (_rear == _front);
    }

    pragma(inline) @property bool full() const
    {
        if ((_rear + 1) % _size == _front)
            return true; //队满
        else
            return false;
    }

    pragma(inline, true) @property T front()
    {
        assert(!empty());
        return _data[_front];
    }

    pragma(inline, true) @property uint length()
    {
        return (_rear - _front + _size) % _size;
    }

    pragma(inline, true) @property uint maxLength() nothrow
    {
        static if (autoExten)
        {
            return uint.max;
        }
        else
        {
            return _size - 1;
        }
    }

	bool enQueue(InsertT x)
    {
        if (full())
        { //队满
            static if (autoExten)
            {
                exten();
            }
            else
            {
                return false;
            }
        }
        _data[_rear] = x;
        _rear = (_rear + 1) % _size; //队尾指针加 1 取模
        return true;
    }

    pragma(inline, true) T deQueue(T v = T.init) nothrow
    {
        assert(!empty());
        auto x = _data[_front];
        _data[_front] = v;
        _front = (_front + 1) % _size; //队头指针加 1 取模
        return x;
    }

    static if (autoExten)
    {
    protected:
        void exten()
        {
            //	writeln("queue auto exten");
            auto size = _size > 128 ? _size + ((_size / 3) * 2) : _size * 2;
            auto len = TSize * size;
            auto data = cast(T[]) _alloc.allocate(TSize * size);
            static if (addToGC && !is(Allocator == GCAllocator))
            {
                GC.addRange(data.ptr, len);
            }

            uint i = 0;
            while (!empty)
            {
                data[i] = deQueue();
                ++i;
            }
            _size = size;
            _front = 0;
            _rear = i;
            static if (addToGC && !is(Allocator == GCAllocator))
            {
                GC.removeRange(_data.ptr);
            }
            _alloc.deallocate(_data);
            _data = data;
            //writeln("queue auto extened size :", _size,"   used size:",length);
        }

    }
private:
    uint _front = 0;
    uint _rear = 0;
    T[] _data = null;
    uint _size;
    static if (stateSize!Allocator == 0)
        alias _alloc = Allocator.instance;
    else
        Allocator _alloc;
}

unittest
{
    import std.stdio;

    auto myq = Queue!(int)(5);
    writeln("init is empty = ", myq.empty);
    foreach (i; 0 .. 13)
    {
        writeln("enQueue i =  ", i, "  en value = ", myq.enQueue(i));
    }
    writeln("end is empty = ", myq.empty);
    writeln("end is full = ", myq.full);
    writeln("size  = ", myq.length);
    int i = 0;
    while (!myq.empty)
    {
        writeln("\n");
        writeln("\tstart while! i = ", i);
        writeln("\tfront is = ", myq.front());
        writeln("\tdeQueue is = ", myq.deQueue());

        ++i;
    }
    writeln("size  = ", myq.length);
    int x = 2;
    myq.enQueue(x);
    writeln("front is = ", myq.front());
    writeln("size  = ", myq.length);
    x = 3;
    myq.enQueue(x);
    writeln("size  = ", myq.length);
    writeln("front is = ", myq.front());
    writeln("deQueue is = ", myq.deQueue());
    writeln("size  = ", myq.length);
    writeln("front is = ", myq.front());
}

