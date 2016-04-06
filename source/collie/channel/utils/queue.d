/* Copyright collied.org 
 */

module collie.channel.utils.queue;
/** 自定义自己的queue的类,非线程安全
 *  @authors : Putao‘s Collie Team
 @date : 2016.1
 */
import core.memory;
import std.experimental.allocator.common;
import std.experimental.allocator.mallocator : AlignedMallocator;
import std.traits;

struct SqQueue(T,bool autoExten = false, bool addToGC = hasIndirections!T, Allocator = AlignedMallocator)
{
	
	this(uint size)
	{
		assert(size > 3);
		_size = size;
		//_data = new T[_size];
		auto len = T.sizeof * _size;
		_data = cast(T[])_alloc.allocate(T.sizeof * size);
		static if(addToGC){
			GC.addRange(_data.ptr,len);
		}
	}
	
	this(uint size,Allocator alloc){
		this._alloc = alloc;
		this(size);
	}
	
	~this()
	{
		clear();
		static if(addToGC){
			GC.removeRange(_data.ptr);
		}
		_alloc.deallocate(_data);
	}
	
	void clear() 
	{
		static if(hasElaborateDestructor!T ) {
			while(!empty){
				auto x = deQueue();
			}
		} else {
			_data[] = T.init;
		}
		_front = _rear = 0;
	}
	
	@property bool empty() const
	{
		if(_rear == _front) return true;  //队空条件
		else return false;
	}
	
	@property bool full() const
	{
		if((_rear + 1) % _size == _front) return true; //队满
		else return false;
	}
	
	@property T front ()
	{
		assert(!empty());
		return _data[_front];
	}
	
	@property uint length()
	{
		return (_rear - _front + _size) % _size;
	}
	
	@property uint maxLength()
	{
		static if(autoExten) {
			return uint.max;
		} else {
			return _size - 1;
		}
	}


	bool enQueue(T x)
	{
		if(full()){ //队满
			static if(autoExten) {
				exten();
			} else {
				return false;
			}
		}
		_data[_rear] = x;
		_rear= (_rear+1) % _size; //队尾指针加 1 取模
		return true;
	}

	T deQueue(T v = T.init)
	{
		assert(!empty());
		auto x = _data[_front];
		_data[_front] = v;
		_front= (_front+1) % _size;  //队头指针加 1 取模
		return x;
	}

	static if (autoExten) {
	protected:
		void exten(){
			//	writeln("queue auto exten");
			auto size = _size > 128 ?  _size + ((_size/3) * 2) : _size * 2;
			auto len = T.sizeof * size;
			auto  data = cast(T[])_alloc.allocate(T.sizeof * size);
			static if(addToGC){
				GC.addRange(data.ptr,len);
			}
			
			uint i  = 0;
			while(!empty) {
				data[i] = deQueue();
				++ i;
			}
			_size = size;
			_front = 0;
			_rear = i;
			static if(addToGC){
				GC.removeRange(_data.ptr);
			}
			_alloc.deallocate(_data);
			_data = data;
			//writeln("queue auto extened size :", _size,"   used size:",length);
		}
		
		
	}
private:
	uint _front = 0;
	uint _rear = 0;
	T[] _data = null;
	uint _size;
	static if (stateSize!Allocator == 0)
		alias _alloc = Allocator.instance;
	else
		Allocator _alloc;
};

unittest{
	import std.stdio;

	auto myq = SqQueue!(int,true,false)(5);
	writeln("init is empty = ",myq.empty);
	foreach(i;0..13){
		writeln("enQueue i =  ",i ,"  en value = ",myq.enQueue(i));
	}
	writeln("end is empty = ",myq.empty);
	writeln("end is full = ",myq.full);
	writeln("size  = ",myq.length);
	int i = 0;
	while(!myq.empty){
		writeln("\n");
		writeln("\tstart while! i = ", i);
		writeln("\tfront is = ",myq.front());
		writeln("\tdeQueue is = ",myq.deQueue());
		
		++ i;
	}
	writeln("size  = ",myq.length);
	int x = 2;
	myq.enQueue(x);
	writeln("front is = ",myq.front());
	writeln("size  = ",myq.length);
	x = 3;
	myq.enQueue(x);
	writeln("size  = ",myq.length);
	writeln("front is = ",myq.front());
	writeln("deQueue is = ",myq.deQueue());
	writeln("size  = ",myq.length);
	writeln("front is = ",myq.front());
}
