module collie.codec.utils.cutpack;

import core.stdc.string;
import core.stdc.stdlib;

import std.bitmanip;

import collie.handler.basehandler;
import collie.channel.pipeline;
import collie.channel.define;

class CutPack(bool littleEndian) : Handler 
{
	this(PiPeline pipu,int maxLen = uint.max)
	{
		super(pip);
		_max = maxLen;
	}

	~this(){
		_packData = null;
	}

	override void inEvent(InEvent event)
	{
		trace("CutPack inEvent ", event.type);
		if(event.type == INEVENT_TCP_READ) {
			scope auto ev = cast(INEventTCPRead)event;
			if(ev.data.length == 0) return;
			readPack(ev.data,event);
		} else {
			event.up();
		}
	}
	
	override void outEvent(OutEvent event)
	{
		trace("CutPack outEvent  ", event.type);
		if(event.type == OutCutPackEvent.type) {
			scope auto ev = cast(OutCutPackEvent)event;
			scope auto oevent = new OutEventTCPWrite(event);
			oevent.data = writePack(ev.data);
			oevent.down();
		} else {
			event.down();
		}
	}

protected:
	void readPack(ubyte[] data,InEvent event)
	{
		if(data.length == 0) return;
		if(_size == 0) {
			uint rang = readPackSize(data);
			if(rang > 0) {
				if(rang < cast(uint)data.length){ 
					data = data[rang..$];
					if(_size == 0) {
						_pSize = 0;
						readPack(data,event);
						return;
					}
				} else { 
					return;
				}
			} else return;
		} 
		ubyte * tptr  = _packData.ptr + _readSize;
		uint size = cast(uint)data.length;
		uint tsize = _size - _readSize;
		if(size >= tsize) {
			memcpy(tptr, data.ptr, tsize);
			_readSize = 0;
			_pSize = 0;
			_size = 0;
			scope InCutPackEvent ev = new InCutPackEvent(event,_packData);
			ev.up();
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
		uint i;
		for(i = 0; _pSize < 4 && i < size; ++i, ++ _pSize){
			_packSize[_pSize] = data[i];
		}
		if(_pSize == 4) {
			static if(littleEndian) {
				_size = littleEndianToNative!uint(_packSize);//littleEndianToNative
			} else  {
				_size = bigEndianToNative!uint(_packSize);//
			}
			_readSize = 0;
			if(_size == 0){
				return i;
			}
			if(_size > _max) {
				mixin(closeChannel("this.pipeline","this"));
				return 0;
			}
			_packData = new ubyte[_size]; //TODO:可优化
			return i;
		} else {
			return 0;
		}
	}

	ubyte[] writePack(ubyte[] edata)
	{
		uint size = cast(uint)edata.length;
		ubyte[] data = new ubyte[size + 4];
		static if(littleEndian) {
			ubyte[4] length = nativeToLittleEndian(size);// nativeToLittleEndian
		} else {
			ubyte[4] length = nativeToBigEndian(size);// nativeToLittleEndian
		}
		ubyte * tdata = data.ptr;
		memcpy(tdata,length.ptr,4);
		tdata += 4;
		memcpy(tdata,edata.ptr,size);
		return data;
	}
private:
	ubyte[] _packData;
	ubyte[4] _packSize;
	uint _size;
	uint _readSize;
	uint _pSize;
	uint _max;
};


class InCutPackEvent : InEvent
{
	shared static this() {
		if(type == 0) {
			type = getEventType();
			trace("InCutPackEvent type", type);
		}
	}
	shared static const uint type;

	ubyte[] data;
	this(const InEvent ev){super(ev,type);}
	@disable this();
	this(const InEvent ev,ubyte[] data){super(ev,type);this.data = data;}
};

class OutCutPackEvent : OutEvent
{
	shared static this() {
		if(type == 0) {
			type = getEventType();
			trace("OutCutPackEvent type", type);
		}
	}
	shared static const uint type;
	
	ubyte[] data;
	
	this(const OutEvent ev) {super(ev,type);}
	this(const PiPeline pip){super(pip,type);}
	@disable this();
	this(const OutEvent ev,ubyte[] data){super(ev,type);this.data = data;}
	this(const PiPeline pip,OutHandle hand){
		super(pip,type,hand);
	}
};



unittest{
	import std.stdio;
	CutPack pack = new CutPack(null);
	ubyte[5] tdata = ['0','0','0','0','0'];
	ubyte[] pdata = pack.writePack(tdata);
	assert(pdata.length == 9);
	writeln("tdata = ", tdata);
	writeln("pdata = ", pdata);
	ubyte[5] tdata2 = ['1','1','1','1','1'];
	pdata ~= pack.writePack(tdata2);
	assert(pdata.length == 18);
	writeln("tdata2 = ", tdata2);
	writeln("pdata = ", pdata);
}
