module collie.codec.http.config;

import std.experimental.allocator;
import std.experimental.allocator.gc_allocator;

final class HTTPConfig
{
    __gshared static uint MaxBodySize = 8*1024*1024;//2M
    __gshared static uint MaxHeaderSize = 16 * 1024;//8K;
    //buffer Size;
    __gshared static uint HeaderStectionSize = 1024;
    __gshared static uint RequestBodyStectionSize = 4096;
    __gshared static uint ResponseBodyStectionSize = 4096;
}


__gshared IAllocator httpAllocator;

shared static this()
{
    import std.experimental.allocator.mallocator;
    
    httpAllocator = allocatorObject(Mallocator.instance);
  // httpAllocator = allocatorObject(GCAllocator.instance);
}
