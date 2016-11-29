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
module collie.utils.memory;

import core.memory;

import std.traits;

pragma(inline, true) void gcFree(T)(T obj) if (is(T == class) || is(T == interface))
{
    destroy(obj);
    GC.free(cast(void*) obj);
}

pragma(inline, true) void gcFree(T)(T* obj)
{
    static if (is(T == struct)) //NOTE: when it call in dstor, the struct's ~this will exec twice.
        destroy((*obj));
    GC.free(obj);
}

pragma(inline, true) void gcFree(void[] obj, bool index = false)
{
    void* t = obj.ptr;
	if(t) {
	    if (index)
	        t = GC.addrOf(t);
	    GC.free(t);
	}
}
