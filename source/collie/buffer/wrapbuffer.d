module collie.buffer.wrapbuffer;

import collie.buffer;
import collie.utils.bytes;

class WrapBuffer : Buffer
{
	this(ubyte[] data, size_t writed = 0)
	{
		_data = data;
		_wsize = writed;
	}
	pragma(inline,true)
		void clear()
	{
		_rsize = 0;
		_wsize = 0;
	}

	override @property bool eof() const
	{
		return (_rsize >= _wsize);
	}
	override size_t read(size_t size, void delegate(in ubyte[]) cback)
	{
		size_t len = _wsize - _rsize;
		len = size < len ? size : len;
		if (len > 0)
			cback(_data[_rsize .. (_rsize + len)]);
		_rsize += len;
		return len;
	}

	override size_t write(in ubyte[] dt)
	{
		size_t len = _data.length - _wsize;
		len = dt.length < len ? dt.length : len;
		if (len > 0)
		{
			_data[_wsize .. (_wsize + len)] = dt[0 .. len];
		}
		return len;
	}

	override void rest(size_t size = 0){
		_rsize = _rsize;
	}

	override size_t readPos() {
		return _rsize;
	}

	ubyte[] data(bool all = false)
	{
		if (all){
			return _data;
		} else if (_wsize == 0){
			return null;
		} else {
			return _data[0 .. _wsize];
		}
	}

	override @property size_t length() const { return _wsize; }
	
	override size_t readLine(void delegate(in ubyte[]) cback) //回调模式，数据不copy
	{
		if(eof()) return 0;
		ubyte[] tdata = _data[_rsize.._wsize];
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
	
	override size_t readAll(void delegate(in ubyte[]) cback)
	{
		if(eof()) return 0;
		ubyte[] tdata = _data[_rsize.._wsize];
		_rsize = _wsize;
		cback(tdata);
		return data.length;
	}
	
	override size_t readUtil(in ubyte[] chs, void delegate(in ubyte[]) cback)
	{
		if(eof()) return 0;
		ubyte[] tdata = _data[_rsize.._wsize];
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
	ubyte[] _data;
	size_t _rsize = 0;
	size_t _wsize = 0;
}

unittest
{
	import std.stdio;
	ubyte[] __buffer = new ubyte[4096];
	string data = "hello world. hello world.\n hello world. hello world. hello \nworld. hello\r\n world. hello world. hello world. hello world. hello world. hello world. hello world. hello world.";
	auto buf = new WrapBuffer(__buffer);
	writeln("buffer write :", buf.write(cast(ubyte[]) data));
	writeln("buffer  size:", buf.length);
	assert(buf.length == data.length);
	ubyte[] dt;
	dt.length = 13;
	writeln("buffer read size =", buf.read(13,(in ubyte[] data2){dt[] = data2[];}));
	writeln("buffer read data =", cast(string) dt);

	
	buf.readLine((in ubyte[] data2){writeln(cast(string)data2);});

}
