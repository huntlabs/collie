module collie.codec.http.httpwritebuffer;

import kiss.container.ByteBuffer;
import kiss.net;
import kiss.event.core;
import kiss.event.task;

@trusted abstract class HttpWriteBuffer : StreamWriteBuffer, WriteBuffer
{
	override abstract size_t write(in ubyte[] data);

	override abstract size_t set(size_t pos, in ubyte[] data);

	override abstract @property size_t length() const;

    void setFinalTask(AbstractTask task){
        _task = task;
    }

    override void doFinish() nothrow{
		if(_task !is null)
        	_task.job();
    }
    StreamWriteBuffer next(){ return _next; }
    void next(StreamWriteBuffer v) { _next = v; }

private:
    StreamWriteBuffer _next;
    AbstractTask _task;
}

class HTTPByteBuffer(Alloc) : HttpWriteBuffer
{
    import kiss.container.ByteBuffer;
    import kiss.container.Vector;
    import std.experimental.allocator.common;

    alias BufferStore = Vector!(ubyte,Alloc); 

    static if (stateSize!(Alloc) != 0)
	{
		this(Alloc alloc)
		{
			_store = BufferStore(1024,alloc);
		}
		
		@property allocator(){return _store.allocator;}
		
	} else {
		this()
		{
			_store = BufferStore(1024);
		}
	}

	~this(){
		destroy(_store);
	}

    override size_t write(in ubyte[] data)
	{
		size_t len = _store.length;
		()@trusted{_store.insertBack(cast(ubyte[])data);}();
		return _store.length - len;
	}

	override size_t set(size_t pos, in ubyte[] data)
	{
		import core.stdc.string : memcpy;
		if(pos >= _store.length || data.length == 0) return 0;
		size_t len = _store.length - pos;
		len = len > data.length ? data.length : len;
		()@trusted{
			ubyte *	ptr = cast(ubyte *)(_store.ptr + pos);
			memcpy(ptr, data.ptr, len);
		}();
		
		return len;
	}

    void rest(size_t size){
		_rsize = size;
	}

    const(ubyte)[] sendData()  
    {
        size_t len = _rsize + 4096;// 一次最大发送4K
		len = _store.length < len ? _store.length : len;
		auto _data = _store.data();
		return _data[_rsize .. len];
    }

    bool popSize(size_t size) 
    {
        _rsize += size;
        return _rsize >= _store.length;
    }

    override void doFinish() {
        _store.clear();
        super.doFinish();
    }

	override size_t length() const{
		return _store.length;
	}
private:
	BufferStore _store;
	size_t _rsize = 0;
}