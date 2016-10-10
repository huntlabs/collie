module collie.codec.http.headers;

import collie.utils.vector;
import std.experimental.allocator.gc_allocator;

public import collie.codec.http.headers.httpcommonheaders;

struct HTTPHeaders
{
	alias HVector = Vector!(string,GCAllocator);
	enum kInitialVectorReserve = 32;

	/**
   * Remove all instances of the given header, returning true if anything was
   * removed and false if this header didn't exist in our set.
   */
	bool remove(string name){return true;}
	bool remove(HTTPHeaderCode code){return true;}
	/**
   * Get the total number of headers.
   */
	size_t size() const;


private:
	Vector!(HTTPHeaderCode,GCAllocator) _codes;
	HVector _headersNames;
	HVector _headerValues;
}