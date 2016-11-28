module collie.buffer.ubytebuffer;

import collie.buffer;
import collie.utils.vector;
import std.experimental.allocator.common;
import collie.utils.bytes;

class UbyteBuffer(Alloc) : Buffer
{
	alias BufferStore = Vector!(ubyte,Alloc,false); 

	static if (stateSize!Alloc != 0)
	{
		this(Alloc alloc)
		{
			_store = BufferStore(1024,alloc);
		}
		
		@property allocator(){return _store.allocator;}
		
	}


	this()
	{
		_store = BufferStore(1024);
	}

	~this(){
		destroy(_store);
	}

	void reserve(size_t elements)
	{
		_store.reserve(elements);
	}

	pragma(inline,true)
		void clear()
	{
		_rsize = 0;
		_store.clear();
	}
	
	override @property bool eof() const
	{
		return (_rsize >= _store.length);
	}

	override size_t read(size_t size,scope  void delegate(in ubyte[]) cback)
	{
		size_t len = _store.length - _rsize;
		len = size < len ? size : len;
		ubyte[] _data = _store.data(false);
		if (len > 0)
			cback(_data[_rsize .. (_rsize + len)]);
		_rsize += len;
		return len;
	}
	
	override size_t write(in ubyte[] dt)
	{
		size_t len = _store.length;
		_store.insertBack(cast(ubyte[])dt);
		return _store.length - len;
	}
	
	override void rest(size_t size = 0){
		_rsize = _rsize;
	}
	
	override size_t readPos() {
		return _rsize;
	}
	
	ubyte[] data(bool all = false)
	{
		ubyte[] _data = _store.data(false);
		if (all){
			return _data;
		} else {
			return _data[_rsize .. $];
		}
	}
	
	override @property size_t length() const { return _store.length; }
	
	override size_t readLine(scope void delegate(in ubyte[]) cback) //回调模式，数据不copy
	{
		if(eof()) return 0;
		ubyte[] _data = _store.data(false);
		ubyte[] tdata = _data[_rsize..$];
		size_t size = _rsize;
		ptrdiff_t index = findCharByte(tdata,cast(ubyte)'\n');
		if(index < 0){
			_rsize += tdata.length;
			cback(tdata);
		} else {
			_rsize += (index + 1);
			size += 1;
			if(index > 0){
				size_t ts = index -1;
				if(_data[ts] == cast(ubyte)'\r') {
					index = ts;
				}
			}
			cback(_data[0..index]);
		}
		
		return _rsize - size;
	}
	
	override size_t readAll(scope void delegate(in ubyte[]) cback)
	{
		if(eof()) return 0;
		ubyte[] _data = _store.data(false);
		ubyte[] tdata = _data[_rsize..$];
		_rsize = _store.length;
		cback(tdata);
		return data.length;
	}
	
	override size_t readUtil(in ubyte[] chs, scope void delegate(in ubyte[]) cback)
	{
		if(eof()) return 0;
		ubyte[] _data = _store.data(false);
		ubyte[] tdata = _data[_rsize..$];
		size_t size = _rsize;
		ptrdiff_t index = findCharBytes(tdata,chs);
		if(index < 0){
			_rsize += tdata.length;
			cback(tdata);
		} else {
			_rsize += (index + chs.length);
			size += chs.length;
			cback(_data[0..index]);
		}
		return _rsize - size;
	}
	
private:
	BufferStore _store;
	size_t _rsize = 0;
}

unittest
{
	import std.stdio;
	import std.experimental.allocator.mallocator;
	string data = "hello world. hello world.\n hello world. hello world. hello \nworld. hello\r\n world. hello world. hello world. hello world. hello world. hello world. hello world. hello world.";
	auto buf = new UbyteBuffer!Mallocator();
	writeln("buffer write :", buf.write(cast(ubyte[]) data));
	writeln("buffer  size:", buf.length);
	assert(buf.length == data.length);
	ubyte[] dt;
	dt.length = 13;
	writeln("buffer read size =", buf.read(13,(in ubyte[] data2){dt[] = data2[];}));
	writeln("buffer read data =", cast(string) dt);
	
	
	buf.readLine((in ubyte[] data2){writeln(cast(string)data2);});
	
}