module collied.codec.ptpack.ptpack;

import collied.handler.basehandler;
import collied.channel.pipeline;
import std.bitmanip;
import core.stdc.string;
import core.stdc.stdlib;
import std.experimental.logger;

string encodePack(string data,string type,string pipeline,string handler){
	string str =  "{ scope auto mixins_event = new EnPackEvent(" ~ pipeline ~ ", " ~ handler ~ ");
    mixins_event.mtype = " ~ type ~ ";
    mixins_event.mdata = " ~ data ~ ";
	mixins_event.down(); }";
	return str;
}

string encodePack(string data,string type,string event){
	string str =  "{ scope auto mixins_event = new EnPackEvent(" ~ event ~ ");
    mixins_event.mtype = " ~ type ~ ";
    mixins_event.mdata = " ~ data ~ ";
	mixins_event.down(); }";
	return str;
}

class PtPack(bool littleEndian) : Handler 
{
	this(PiPeline pip,uint maxLen = uint.max)
	{
		super(pip);
		_max = maxLen;
	}
	~this(){
		//destroy(_packData);
		_packData = null;
	}

	override void inEvent(InEvent event)
	{
		trace("PtPack inEvent ", event.type);
		if(event.type == INEVENT_TCP_READ) {
			scope auto ev = cast(INEventTCPRead)event;
			if(ev.data.length == 0) return;
			readPack(ev.data,event);
		} else if(event.type == INEVENT_TCP_CLOSED){
			_packData = null;
			_size = 0;
			_readSize = 0;
			_pSize = 0;
			_tSize = 0;
		}else{
			event.up();
		}
	}
	
	override void outEvent(OutEvent event)
	{
		trace("PtPack outEvent  ", event.type);
		if(event.type == EnPackEvent.type) {
			scope auto ev = cast(EnPackEvent)event;
			mixin(writeChannel("event","writePack(ev.mtype,ev.mdata)"));
		} else {
			event.down();
		}
	}

protected:
	void readPack(ubyte[] data,InEvent event)
	{
		trace(" data.length  ", data.length);
		if(data.length == 0) return;
		if(_size == 0) {
			int rang = readType(data);
			if(rang >= 0 && rang < cast(uint)data.length) {
				data = data[rang..$];
			} else {
				return;
			}
			rang = readPackSize(data);
			if(rang >= 0) {
				if(rang < cast(uint)data.length){ 
					data = data[rang..$];
				} else { 
					data = null;
				} 
				if(_size == 0) {
					scope DePackEvent ev = new DePackEvent(event,null);
					static if(littleEndian) {
						ev.mtype = littleEndianToNative!ushort(_typeSize);//littleEndianToNative
					} else  {
						ev.mtype = bigEndianToNative!ushort(_typeSize);
					}
					ev.mlength = 0;
					ev.up();
					_pSize = 0;
					_tSize = 0;
					readPack(data,event);
				}
			} else{ 
				return;
			}
		}
		if(data.length == 0) return;
		uint size = cast(uint)data.length;
		uint tsize = _size - _readSize;
		ubyte * tptr  = _packData.ptr + _readSize;
		if(size >= tsize) {
			memcpy(tptr, data.ptr, tsize);
			_readSize = 0;
			_pSize = 0;
			_tSize = 0;
			scope DePackEvent ev = new DePackEvent(event,_packData);
			static if(littleEndian) {
				ev.mtype = littleEndianToNative!ushort(_typeSize);//littleEndianToNative
			} else  {
				ev.mtype = bigEndianToNative!ushort(_typeSize);
			}
			ev.mlength = _size;
			ev.up();
			_size = 0;
			if(size == tsize) return;
			size = 0;
			data = data[tsize..$];
			readPack(data,event);
		} else {
			memcpy(tptr,data.ptr,size);
			_readSize += size;
		}
	}

	
	uint readPackSize(ref ubyte[] data)
	{
		if(_pSize == 4 || _size > 0) return 0;
		uint size = cast(uint)data.length;
		int i;
		for(i = 0; _pSize < 4 && i < size; ++i, ++ _pSize){
			_packSize[_pSize] = data[i];
		}
		if(_pSize == 4) {
			static if(littleEndian) {
				_size = littleEndianToNative!uint(_packSize);//littleEndianToNative
			} else  {
				_size = bigEndianToNative!uint(_packSize);//
			}
			if(_size > _max) {
				mixin(closeChannel("this.pipeline","this"));
				return -1;
			}
			_readSize = 0;
			if(_size == 0){
				return i;
			}
			_packData = new ubyte[_size]; //TODO:可优化
			return i;
		} else {
			return -1;
		}
	}

	uint readType(ref ubyte[] data)
	{
		
		if(_tSize == 2) return 0;
		uint size = cast(uint)data.length;
		int i;
		for(i = 0; _tSize < 2 && i < size; ++i, ++ _tSize){
			_typeSize[_tSize] = data[i];
		}
		if(_tSize == 2) {
			return i;
		} else {
			return -1;
		}
	}

	ubyte[] writePack(ushort type,ubyte[] edata)
	{
		uint size = cast(uint)edata.length;
		ubyte[] data = new ubyte[size + 6];
		static if(littleEndian) {
			ubyte[4] length = nativeToLittleEndian(size);// nativeToLittleEndian
			ubyte[2] ttype =  nativeToLittleEndian(type);
		} else {
			ubyte[4] length = nativeToBigEndian(size);// nativeToLittleEndian
			ubyte[2] ttype =  nativeToBigEndian(type);
		}
		ubyte * tdata = data.ptr;
		memcpy(tdata,ttype.ptr,2);
		tdata += 2;
		memcpy(tdata,length.ptr,4);
		tdata += 4;
		memcpy(tdata,edata.ptr,size);
		return data;
	}
private:
	ubyte[] _packData;
	ubyte[4] _packSize;
	ubyte[2] _typeSize;
	uint _size;
	uint _readSize;
	uint _pSize;
	uint _tSize;
	uint _max;
	//ushort _type;
};


class DePackEvent : InEvent
{
	shared static this() {
		if(type == 0) {
			type = getEventType();
			trace("DePackEvent type", type);
		}
	}
	shared static const uint type;

	ubyte[] mdata;
	uint mlength;
	ushort mtype;
	this(const InEvent ev){super(ev,type);}
	@disable this();
	this(const InEvent ev,ubyte[] data){super(ev,type);this.mdata = data;}
};

class EnPackEvent : OutEvent
{
	shared static this() {
		if(type == 0) {
			type = getEventType();
			trace("EnPackEvent type", type);
		}
	}
	shared static const uint type;
	
	ubyte[] mdata;
	ushort mtype;
	this(const OutEvent ev) {super(ev,type);}
	this(const PiPeline pip){super(pip,type);}
	@disable this();
	this(const OutEvent ev,ubyte[] data){super(ev,type);this.mdata = data;}
	this(const PiPeline pip,OutHandle hand){
		super(pip,type,hand);
	}
};
