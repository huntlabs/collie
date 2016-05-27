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
module collie.utils.allocator;
import core.memory;

import std.experimental.allocator.mallocator;

struct MallocatorToGC
{
    enum uint alignment = Mallocator.alignment;

    @trusted @nogc nothrow void[] allocate(size_t bytes) shared
    {
        auto p = Mallocator.instance.allocate(bytes);
        if (p !is null)
            GC.addRange(p.ptr, p.length);
        return p;
    }

    @system @nogc nothrow bool deallocate(void[] b) shared
    {
        GC.removeRange(b.ptr);
        Mallocator.instance.deallocate(b);
        return true;
    }

    @system @nogc nothrow bool reallocate(ref void[] b, size_t s) shared
    {
        auto t = b.ptr;

        if (Mallocator.instance.reallocate(b, s))
        {
            GC.removeRange(t);
            GC.addRange(b.ptr, b.length);
            return true;
        }
        return false;
    }

    static shared MallocatorToGC instance;
}
