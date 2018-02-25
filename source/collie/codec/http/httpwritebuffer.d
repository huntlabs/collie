module collie.codec.http.httpwritebuffer;

import kiss.buffer;
import kiss.net.struct_;
import kiss.event.task;

import std.experimental.logger;
import std.array;

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
private:
    AbstractTask _task;
}

class HTTPByteBuffer : HttpWriteBuffer
{
	alias BufferStore = Appender!(ubyte[]);
	this()
	{
		// _store = BufferStore(1024);
	}


    override size_t write(in ubyte[] data)
	{
		size_t len = _store.data.length;
		_store.put(data);
		return data.length;
	}

	override size_t set(size_t pos, in ubyte[] data)
	{
		import core.stdc.string : memcpy;
		if(pos >= _store.data.length || data.length == 0) return 0;

		size_t len = _store.data.length - pos;
		len = len > data.length ? data.length : len;
		_store.data[pos..len] = data[0..len];
		return len;
	}

    void rest(size_t size){
		_rsize = size;
	}

    override const(ubyte)[] sendData() nothrow 
    {
        size_t len = _rsize + 4096;// 一次最大发送4K
		ubyte[] buffer = _store.data();
		len = buffer.length < len ? buffer.length : len;
		return buffer[_rsize .. len];
    }

	const(ubyte)[] allData() nothrow 
    {
		return _store.data();
    }

    override bool popSize(size_t size) nothrow
    {
        _rsize += size;
        return _rsize >= _store.data.length;
    }

    override void doFinish() nothrow{
        _store.clear();
        super.doFinish();
    }

	override size_t length() const{
		return _store.data.length;
	}
private:
	BufferStore _store;
	size_t _rsize = 0;
}