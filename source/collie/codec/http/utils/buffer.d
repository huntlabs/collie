module collie.codec.http.utils.buffer;

import std.container.array;
import core.stdc.string;
import std.string;
import std.experimental.allocator ;
import std.experimental.allocator.mallocator;
import core.memory;

shared static this()
{
	sectionBufferAllocator = allocatorObject(AlignedMallocator.instance);
}

__gshared IAllocator sectionBufferAllocator; 


interface Buffer
{
	@property bool eof() const;
	ulong read(ulong size ,void delegate(in ubyte[]) cback);
	ulong write(in ubyte[] data);
	void rest(ulong size = 0);
	@property ulong length()  const;
}


final class OneBuffer : Buffer
{
	this(ubyte[] buf, uint writed = 0)
	{
		_data = buf;
		_wSize = 0;
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

	override @property ulong length()  const  {return _wSize;}

	override ulong read(ulong size ,void delegate(in ubyte[]) cback)
	{
		ulong len = _wSize - _rSize;
		len = size < len ? size : len;
		if(len > 0)
			cback(_data[_rSize..(_rSize + len)]);
		_rSize += len;
		return len;
	}

	override ulong write(in ubyte[] dt)
	{
		ulong len = _data.length - _wSize;
		len = dt.length < len ? dt.length : len;
		if(len > 0){
			_data[_wSize..(_wSize + len)] = dt[0..len];
		}
		return len;
	}

	ubyte[] data(bool all = false){
		if(all) {
			return _data;
		} else if(_wSize == 0){
			return null;
		} else {
			return _data[0.._wSize];
		}
	}

	override void rest(ulong size = 0){_rSize = size;}
private:
	ubyte[] _data;
	ulong _wSize;
	ulong _rSize = 0;
}

final class SectionBuffer : Buffer
{
	this(ulong sectionSize, IAllocator clloc = sectionBufferAllocator)
	{
		_alloc = clloc;
		_sectionSize = sectionSize;
	}
	
	~this(){
		if(eof()) return;
		for (size_t i = 0; i < _buffer.length; ++i){
			if(!GC.addrOf(_buffer[i].ptr)) //不是GC的内存就释放
				_alloc.deallocate(_buffer[i]);
			_buffer[i] = null;
		}
		_buffer.clear();
	}
	
	void reserve(ulong size) 
	{ 
		assert(size > 0);
		ulong sec_size =  size / _sectionSize;
		if(sec_size < _buffer.length){
			for (size_t i = sec_size; i < _buffer.length; ++i){
				if(_buffer[i] !is null) {
					_alloc.deallocate(_buffer[i]);
					_buffer[i] = null;
				}
			}
			_buffer.removeBack(_buffer.length - sec_size);
		} else if (_buffer.length < sec_size) {
			ulong a_size = sec_size - _buffer.length;
			for (ulong i = 0; i < a_size; ++i){
				_buffer.insertBack(cast(ubyte[])_alloc.allocate(_sectionSize));//new ubyte[_sectionSize]);//
			}
		}
		ulong lsize = size - (_buffer.length * _sectionSize);
		_buffer.insertBack(cast(ubyte[])_alloc.allocate(lsize));//new ubyte[lsize]);
		_rSize = 0;
		_wSize = 0;
	}
	
	ulong maxSize()
	{
		if (_buffer.empty()) return ulong.max;
		ulong leng = _buffer[_buffer.length - 1].length;
		if (leng == _sectionSize) return ulong.max;
		else {
			return (_buffer.length - 1) * _sectionSize + leng;
		}
	}
	
	@property void clear()
	{
		if(eof()) return;
		for (size_t i = 0; i < _buffer.length; ++i){
			_alloc.deallocate(_buffer[i]);
			_buffer[i] = null;
		}
		_buffer.clear();
		_rSize = 0;
		_wSize = 0;
	}
	
	@property void clearWithOutMemory()
	{
		if(maxSize() != ulong.max){
			_alloc.deallocate(_buffer[_buffer.length - 1]);
			_buffer.removeBack();
		}
		_rSize = 0;
		_wSize = 0;
	}
	
	ulong swap(Array!(ubyte[]) * uarray)
	{
		auto size = _wSize;
		import std.algorithm : swap;
		swap((*uarray),_buffer);
		_rSize = 0;
		_wSize = 0;
		return size;
	}
	
	override  @property bool eof() const
	{
		return (_rSize >= _wSize) ;
	}
	
	override void rest(ulong size = 0){_rSize = size;}

	override @property ulong length()  const  {return _wSize;}
	@property ulong stectionSize(){return _sectionSize;}
	
	ulong read(ubyte[] data) {
		ulong rlen = 0;	
		return read(data.length,delegate(in ubyte[] dt){
				//writeln("read data = : ", cast(string)dt);
				memcpy((data.ptr + rlen),dt.ptr,dt.length);
				rlen += dt.length;
			});
		
	}
	
	override ulong read(ulong size ,void delegate(in ubyte[]) cback) //回调模式，数据不copy
	{
		ulong len = _wSize - _rSize;
		ulong maxlen = size < len ? size : len;
		ulong rcount = readCount();
		ulong rsite = readSite() ;
		ulong rlen = 0, tlen;
		while (rcount < _buffer.length) {
			ubyte[] by = _buffer[rcount];
			tlen = maxlen -rlen;
			len = by.length - rsite;
			if(len >= tlen){
				// memcpy((data.ptr + rlen),(by.ptr + rsite),tlen);
				cback(by[rsite..(tlen + rsite)]);
				rlen += tlen;
				_rSize += tlen;
				break;
			} else {
				// memcpy((data.ptr + rlen),(by.ptr + rsite),len);
				cback(by[rsite..$]);
				_rSize += len;
				rlen += len;
				rsite = 0;
				++rcount;
			}
		}
		//_rSize += maxlen;
		return maxlen;
	}
	
	override ulong write(in ubyte[] data)
	{
		ulong len = maxSize() - _wSize;
		ulong maxlen = data.length < len ? data.length : len;
		ulong wcount = writeCount();
		ulong wsite = writeSite();
		ulong wlen = 0, tlen;
		ulong maxSize = maxSize;
		while (_wSize < maxSize) {
			if(wcount == _buffer.length) {
				_buffer.insertBack(cast(ubyte[])_alloc.allocate(_sectionSize));//new ubyte[_sectionSize]);//
			}
			ubyte[] by = _buffer[wcount];
			tlen = maxlen - wlen;
			len = by.length - wsite;
			if(len >= tlen){
				memcpy((by.ptr + wsite),(data.ptr + wlen),tlen);
				//_wSize += tlen;
				break;
			} else {
				memcpy((by.ptr + wsite),(data.ptr + wlen),len);
				// _wSize += len;
				wlen += len;
				wsite = 0;
				++ wcount;
			}
		}
		_wSize += maxlen;
		return maxlen;
	}
	
	ubyte[] readLine(bool hasRN = false)()//返回的数据有copy
	{
		ubyte[]  rbyte;
		auto len = readLine!(hasRN)(delegate(in ubyte[] data){
				rbyte ~= data;
			});
		return rbyte;
	}
	
	ulong readLine(bool hasRN = false)(void delegate(in ubyte[]) cback) //回调模式，数据不copy
	{
		if(eof())return 0;
		ulong rcount = readCount();
		ulong rsite = readSite() ;
		//bool crcf = false;
		ulong size = _rSize;
		ubyte[] rbyte;
		ulong wsite = writeSite();
		ulong wcount = writeCount();
		ubyte[] byptr,by;
		while (rcount <= wcount && !eof()) {
			by = _buffer[rcount];
			if(rcount == wcount) {
				byptr = by[rsite..wsite];
			} else {
				byptr = by[rsite..$];
			}
			auto site = indexOf(cast(string)byptr,'\n');
			if(site == -1){
				if(rbyte.length > 0) {
					cback(rbyte);
					rbyte = null;
				}
				rbyte = byptr;
				rsite = 0;
				++rcount;
				_rSize += rbyte.length;
			} else if(rbyte.length > 0 && site == 0){
				++_rSize;
				static if(!hasRN) {
					auto len = rbyte.length - 1;
					if (rbyte[len] == '\r') {
						if(len == 0) { _rSize += _rSize; return _rSize - size;}
						rbyte = rbyte[0..len];
					}
				}
				cback(rbyte);
				static if(hasRN){
					cback(byptr[0..1]);
				}
				rbyte = null;
				break;
			} else {
				++_rSize;
				if(site == 0)
				{ 
					static if(hasRN){
						cback(byptr[0..1]);
					}
					return _rSize - size;
				}
				cback(rbyte);
				rbyte = null;
				rbyte = byptr[0..(site+1)];
				_rSize += site;//rbyte.length;
				static if(!hasRN) {
					auto len = rbyte.length - 2;
					if (rbyte[len] == '\r') {
						if(len == 0) return _rSize - size;
						rbyte = rbyte[0..len];
					}
				}
				cback(rbyte);
				rbyte = null;
				break;
			}
		}
		
		if(rbyte.length > 0) { cback(rbyte);}
		return _rSize - size;
	}
	
	ulong readAll(void delegate(in ubyte[]) cback)//回调模式，数据不copy
	{
		ulong maxlen = _wSize - _rSize;
		ulong rcount = readCount();
		ulong rsite = readSite() ;
		ulong wcount = writeCount();
		ulong wsize = writeSite();
		ubyte[] rbyte;
		while (rcount <= wcount && !eof()) {
			ubyte[] by = _buffer[rcount];
			if(rcount == wcount){
				rbyte = by[rsite..wsize];
			} else {
				rbyte = by[rsite..$];
			}
			cback(rbyte);
			_rSize += rbyte.length;
			rsite = 0;
			++rcount;
		}
		return _wSize - _rSize;
	}
	
	ubyte[] readAll()//返回的数据有copy
	{
		ubyte[]  rbyte;
		auto len = readAll(delegate(in ubyte[] data){
				rbyte ~= data;
			});
		return rbyte;
	}
	
	ulong readUtil(in ubyte[] data,void delegate(in ubyte[]) cback) //data.length 必须小于分段大小！
	{
		if(data.length == 0 || eof() || data.length >= _sectionSize) return 0;
		auto ch = data[0];
		ulong rcount = readCount();
		ulong rsite = readSite() ;
		ulong size = _rSize;
		ulong wsite = writeSite();
		ulong wcount = writeCount();
		ubyte[] byptr,by;
		while (rcount <= wcount && !eof()) {
			by = _buffer[rcount];
			if(rcount == wcount) {
				byptr = by[rsite..wsite];
			} else {
				byptr = by[rsite..$];
			}
			auto site = indexOf(cast(string)byptr, ch);
			if(site == -1){
				cback(byptr);
				rsite = 0;
				++rcount;
				_rSize += byptr.length;
			} else {
				auto tsize = (_rSize + site);
				ulong i = 1;
				for (++tsize; i < data.length && tsize < _wSize; ++i, ++ tsize){
					//   writeln("i = ", i ,"  tsize = ",tsize);
					//  writeln("data [i] = ", data[i], " this[tsize] = ",this[tsize]);
					if(data[i] != this[tsize]){
						ulong count = tsize / _sectionSize;
						if(count > rcount) {
							cback(byptr);
							_rSize += byptr.length;
							rcount = count;
							by = _buffer[rcount];
							rsite = tsize - _rSize;
							cback(by[0..rsite]);
							_rSize = tsize;
						} else {
							rsite = tsize - _rSize;
							cback(byptr[0..rsite]);
							_rSize = tsize;
						}
						goto next; //没找对，进行下次查找
					} else {
						continue;
					}
				}//循环正常执行完毕,表示
				_rSize = tsize;
				cback(byptr[0..site]);
				return (_rSize - size);
				
			next:
				continue;
			}
		}
		return (_rSize - size);
	}
	
	ref ubyte opIndex(ulong i){
		assert(i < _wSize);
		ulong count = i / _sectionSize;
		ulong site = i % _sectionSize;
		return _buffer[count][site];
	}
	
	@property ulong readSize() const {return _rSize;}
	@property uint readCount() const {return cast(uint)(_rSize / _sectionSize);}
	@property uint readSite()  const  {return cast(uint)(_rSize % _sectionSize);}
	@property uint writeCount()  const {return cast(uint)(_wSize / _sectionSize);}
	@property uint writeSite()  const {return cast(uint)(_wSize % _sectionSize);}
private:
	ulong _rSize;
	ulong _wSize;
	Array!(ubyte[]) _buffer;
	ulong _sectionSize;
	IAllocator _alloc;
}

unittest {
	import std.stdio;
	
	string data = "hello world. hello world. hello world. hello world. hello world. hello world. hello world. hello world. hello world. hello world. hello world. hello world. hello world.";
	auto  buf = new SectionBuffer(5);
	buf.reserve(data.length);
	writeln("buffer max size:", buf.maxSize());
	writeln("buffer  size:", buf.size());
	writeln("buffer write :", buf.write(cast(ubyte[])data));
	writeln("buffer  size:", buf.size());
	ubyte[] dt;
	dt.length = 13;
	writeln("buffer read size =",buf.read(dt));
	writeln("buffer read data =",cast(string)dt);
	
	writeln("\r\n");
	
	auto buf2 = new SectionBuffer(3);
	writeln("buffer2 max size:", buf2.maxSize());
	writeln("buffer2  size:", buf2.size());
	writeln("buffer2 write :", buf2.write(cast(ubyte[])data));
	writeln("buffer2  size:", buf2.size());
	ubyte[] dt2;
	dt2.length = 13;
	writeln("buffer2 read size =",buf2.read(dt2));
	writeln("buffer2 read data =",cast(string)dt2);
	
	writeln("\r\nswitch \r\n");
	
	Array!(ubyte[]) tary;
	buf.swap(&tary);
	writeln("buffer  size:", buf.size());
	writeln("buffer max size:", buf.maxSize());
	writeln("Array!(ubyte[]) length : ", tary.length);
	ulong len = tary.length < 5 ? tary.length : 5;
	for (ulong i = 0; i < len; ++i){
		write("i = ", i);
		writeln("   ,ubyte[] = ",cast(string)tary[i]);
	}
	
	buf.reserve(data.length);
	writeln("buffer max size:", buf.maxSize());
	writeln("buffer  size:", buf.size());
	writeln("buffer write :", buf.write(cast(ubyte[])data));
	writeln("buffer  size:", buf.size());
	writeln("\n 1.");
	dt  = buf.readLine!false();
	writeln("buffer read line size =",dt.length);
	writeln("buffer readline :", cast(string)dt);
	writeln("read size : ",buf._rSize);
	writeln("\n 2.");
	
	/* dt.length = 1;
    writeln("buffer read size =",buf.read(dt));
    writeln("buffer read data =",cast(string)dt);*/
	
	dt = buf.readLine!false();
	writeln("buffer read line size =",dt.length);
	writeln("buffer read line data =",cast(string)dt);
	writeln("read size : ",buf._rSize);
	writeln("\n 3.");
	
	dt = buf.readLine!false();
	writeln("buffer read line size =",dt.length);
	writeln("buffer read line data =",cast(string)dt);
	writeln("read size : ",buf._rSize);
	buf.rest();
	int j = 0;
	while(!buf.eof()) {
		++j;
		writeln("\n ",j," . ");
		dt     = buf.readLine!false();
		writeln("buffer read line size =",dt.length);
		writeln("buffer readline :", cast(string)dt);
		writeln("read size : ",buf._rSize);
	}
	
	data = "ewarwaerewtretr54654654kwjoerjopiwrjeo;jmq;lkwejoqwiurwnblknhkjhnjmq1111dewrewrjmqrtee";
	buf = new SectionBuffer(5);
	// buf.reserve(data.length);
	writeln("buffer max size:", buf.maxSize());
	writeln("buffer  size:", buf.size());
	writeln("buffer write :", buf.write(cast(ubyte[])data));
	writeln("buffer  size:", buf.size());
	
	foreach(i;0..4) {
		ubyte[] tbyte;
		writeln("\n\nbuffer readutil  size:", buf.readUtil(cast(ubyte[])"jmq",delegate(in ubyte[] data){
					//writeln("\t data :", cast(string)data);
					//writeln("\t read size: ", buf._rSize);
					tbyte ~= data;
				}));
		if(tbyte.length > 0) {
			writeln("\n buffer readutil data:", cast(string)tbyte);
			writeln("\t _Rread size: ", buf._rSize);
			writeln("\t _Wread size: ", buf._wSize);
		} else {
			writeln("\n buffer readutil data eof");
		}
	}
	//buf.clear();
	//buf2.clear();
	writeln("hahah");
	destroy(buf);
	destroy(buf2);
}