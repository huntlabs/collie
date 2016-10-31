module collie.utils.bytes;

import core.stdc.string;
import std.traits;

ptrdiff_t findCharByte(T)(in T[] data, in T ch) if(isCharByte!(T))
{
	if(data.length == 0)
		return -1;
	ptrdiff_t index = -1;
	auto ptr = memchr(data.ptr,ch,data.length);
	if(ptr !is null){
		index = cast(ptrdiff_t)((cast(ubyte *) ptr) - data.ptr);
	}

	return index;
}

ptrdiff_t findCharBytes(T)(in T[] data, in T[] chs) if(isCharByte!(T))
{
	if(data.length < chs.length || data.length == 0 || chs.length == 0 )
		return -1;
	ptrdiff_t index = -1;
	size_t rsize = 0;
	while(rsize < data.length){
		auto tdata = data[rsize..$];
		auto ptr = memchr(tdata.ptr,chs[0],tdata.length);
		if(ptr is null) break;

		size_t fistindex = (cast(ubyte *) ptr) - data.ptr;
		if(tdata.length - fistindex < chs.length) 
			break;

		size_t i = 1;
		size_t j = fistindex + 1;
		while(i < chs.length && j < tdata.length){
			if(chs[i] != tdata[j]){
				rsize += fistindex + 1;
				goto next;
			}
			++i; ++j;
		}
		index = cast(ptrdiff_t)fistindex;
		break;
	next:
		continue;
	}
	return index;

//	auto ptr = memchr(data.ptr,chs[0],data.length);
//	if(ptr !is null){
//		size_t fistindex = (cast(ubyte *) ptr) - data.ptr;
//		size_t len = data.length - fistindex;
//		if(len < chs.length) 
//			return -1;
//		size_t i = 1;
//		size_t j = fistindex + 1;
//		while(i < chs.length && j < data.length){
//			if(chs[i] != data[j]){
//				auto tdata = data[(fistindex + 1)..$];
//				return findCharBytes!T(tdata,chs);
//			}
//			++i;
//			++j;
//		}
//		return cast(ptrdiff_t)fistindex;
//	}
//	
//	return -1;
}


template isMutilCharByte(T)
{
	enum bool isMutilCharByte = is(T == byte) || is(T == ubyte) || is(T == char) ;
}

template isCharByte(T)
{
	enum bool isCharByte = is(Unqual!T == byte) || is(Unqual!T == ubyte) || is(Unqual!T == char) ;
}
