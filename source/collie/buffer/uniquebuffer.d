module collie.buffer.uniquebuffer;


import collie.buffer.buffer;

import  std.experimental.allocator.mallocator;

/**
 * 唯一生命周期的buffer，对象析构的时候会释放掉所管理的buffer内存，不可转移。
 * 主要用于Socket读取出来的数据，内存分配采取对齐分配，
 */ 

final class UniqueBuffer : Buffer
{
	this(uint maxLength)
	{
		if (maxLength == 0) maxLength = 2;
		_data = cast(ubyte[])(AlignedMallocator.instance.allocate(maxLength * ubyte.sizeof));
	}

	~this()
	{
		AlignedMallocator.instance.deallocate(_data);
	}
	
	override @property bool eof() const
	{
		return _rsite == _wsite ;
	}

	override size_t read(size_t size ,void delegate(in ubyte[]) cback)
	{
		if(eof) return 0;
		size_t len = _wsite - _rsite;
		len = size > len  ? len : size;
		cback(_data[_rsite..(_rsite + len)]);
		_rsite += len;
		return size;
	}

	override size_t write(in ubyte[] data){
		size_t len = data.length;
		size_t tlen  = _data.length - _wsite;
		len = len >  tlen ? tlen : len;
		_data[_wsite..(_wsite + len)] = data[0..len];
		_wsite += len;
		return len;
	}
	override void rest(size_t size = 0)
	{
		_rsite = size;
	}
	
	override @property size_t length()  const
	{
		return _wsite;
	}

	void setLength(size_t size) nothrow 
	{
		_wsite = size > maxLength ? maxLength : size;
	}

	@property maxLength() const {return _data.length;}

	/** 
	 *  注意：返回的是引用，如果UniqueBuffer销毁，那么buffer也会销毁。
	 */
	@property data(){if(eof)return null; else return _data[_rsite.._wsite];}

	@property usedData(){return _data[0.._wsite];}

	@property beginPtr() {return _data.ptr;}


	@property allData(){return _data;}
private:
	size_t _rsite = 0;
	size_t _wsite = 0;
	ubyte[] _data;
}
