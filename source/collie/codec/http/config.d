module collie.codec.http.config;

import std.experimental.allocator;
import std.experimental.allocator.gc_allocator;

final class HTTPConfig
{
    uint maxBodySize = 8 * 1024 * 1024; //2M
    uint maxHeaderSize = 16 * 1024; //8K;
    //buffer Size;
    uint headerStectionSize = 1024;
    uint requestBodyStectionSize = 4096;
    uint responseBodyStectionSize = 4096;
}

__gshared IAllocator httpAllocator;
__gshared HTTPConfig httpConfig;

shared static this()
{
    import std.experimental.allocator.mallocator;

    httpAllocator = allocatorObject(Mallocator.instance);
    // httpAllocator = allocatorObject(GCAllocator.instance);
    
    httpConfig = new HTTPConfig;
}
