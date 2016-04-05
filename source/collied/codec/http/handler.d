module collied.codec.http.handler;

import collied.handler.basehandler;
import collied.channel;
public import collied.codec.http.utils.buffer;
public import collied.codec.http.header;
public import collied.codec.http.request;
public import collied.codec.http.response;
public import collied.codec.http.config;
import collied.codec.http.utils.frame;

import std.base64;
import std.digest.sha;
import std.bitmanip;

import core.stdc.string;

enum WebSocketGuid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

abstract class WebSocket
{
	final  bool ping(ubyte[] data)
	{
		if(_hand)return _hand.ping(data);
		else return false;
	}
	final bool sendText(string text)
	{
		if(_hand){
			return _hand.send(cast(ubyte[])text,false);
		} else {
			return false;
		}
	}
	
	final bool sendBinary(ubyte[] data)
	{
		if(_hand)return _hand.send(data,true);
		else return false;
	}
	
	final void close()
	{
		if(_hand) _hand.doClose();
	}
	
	final @property Address remoteAdress() {return _addr;}
	
	void onClose();
	void onTextFrame(Frame frame);
	void onPongFrame(Frame frame);
	void onBinaryFrame(Frame frame);
	
package:
	HTTPHandle _hand;
	Address _addr;
}


final class HTTPHandle : Handler
{
	this(PiPeline pip,in Duration timeout = 20.seconds) 
	{
		super(pip);
		_req = new HTTPRequest();
		_res = new HTTPResponse();
		_res.sentCall = &responseDone;
		_res.closeCall = &responseClose;
		_req.headerComplete = &reqHeaderDone;
		_req.requestComplete = &requestDone;
		_tm = new Timer((cast(PiPeline)pipeline).channel.eventLoop);
		_tm.once = false;
		_tm.TimeOut = timeout;
		_tm.setCallBack(&timeOut);
	}

	~this(){
		_req.destroy;
		_req = null;
		_res.destroy;
		_res = null;
		_tm.destroy;
		_tm = null;
		if(_frame) _frame.destroy;
	}

	static int i = 0; //Test Mondy
	string name;

	override void inEvent(InEvent event)
	{

		switch(event.type){
			case INEVENT_TCP_READ:
			{
				trace("in event typre = INEVENT_TCP_READ");
				scope auto ev = cast( INEventTCPRead) event;
				_timeOut = false;
				if(_socket){
					_frame.readFrame(ev.data,&doFrame);
				} else if(!_req.parserData(ev.data)){
					error("http parser erro :", _req.parser.errorString);
					mixin(closeChannel("pipeline","this"));
				}
			}
				break;
			case INEVENT_WRITE:
			{
				trace("in event typre= INEVENT_WRITE");
				scope auto ev = cast(INEventWrite) event;
				threadColliedAllocator.deallocate(ev.data);
				--_writeStection;
				if(_shouldClose && _writeStection == 0) {
					trace("_writeStection ==0 Do close");
					mixin(closeChannel("pipeline","this"));
				}
			}
				break;
			case INEVENT_TCP_CLOSED:
			{
				trace("in event typre = INEVENT_TCPCLOSE");
				_tm.kill();
				scope auto ev = cast(InEventTCPClose) event;
				foreach(ref data ; ev.buffers) {
					threadColliedAllocator.deallocate(data);
				}
				if(_socket){
					_socket.onClose();
					_socket = null;
				}
				clear();
			}
				break;
			case INEVENT_STATUS_CHANGED :
			{
				scope auto ev = cast(INEventSocketStatusChanged)event;
				if(ev.status_to == SOCKET_STATUS.CONNECTED || ev.status_to == SOCKET_STATUS.SSLHandshake){
					if(_tm.isInValid) {
						_tm.start();
					} else {
						_timeOut = false;
					}
				}
			}
				break;
			default:
				trace("in event typre= ", event.type);
				event.up();
				break;
		}
	}

	override void outEvent(OutEvent event) {
	}

protected:
	void responseDone(HTTPResponse respon)
	{
		trace("responseDone");
		if((cast(PiPeline)pipeline).channel.isInValid()) return;
		scope auto buffer = new SectionBuffer(HTTPConfig.instance.Header_Stection_Size,threadColliedAllocator);
		HTTPResponse.generateHeader(respon,buffer);
		auto buf = respon.HTTPBody;
		_writeStection += (buffer.writeCount + 1);
		if(!writeStection(buffer)){
			mixin(closeChannel("pipeline","this"));

			_shouldClose = true;
			return;
		}
		_writeStection += (buf.writeCount + 1);
		writeStection(buf);
		
	}

	void  responseClose(HTTPResponse respon)
	{
		mixin(closeChannel("pipeline","this"));
	}

	void reqHeaderDone(HTTPHeader header)
	{
		trace("reqHeaderDone");
		if(header.upgrade){
			doUpgrade();
		}
	}
	void requestDone(HTTPRequest req)
	{
		trace("requestDone");
		if(pipeline.channel.isInValid()) return;
			switch(pipeline.channel.type) {
				case CHANNEL_TYPE.TCP_Socket:
				{
					auto tcp = cast(TCPSocket)pipeline.channel;
					_req.clientAddress = tcp.remoteAddress;
				} 
					break;
					version(SSL){
						case CHANNEL_TYPE.SSL_Socket:
						{
							auto tcp = cast(SSLSocket)pipeline.channel;
							_req.clientAddress = tcp.remoteAddress;
						} 
						break;
					}
				default:
					mixin(closeChannel("pipeline","this"));
					return;
			}
			if(req.header.httpVersion == HTTPVersion.HTTP1_0){_shouldClose = true;}
			auto handle = HTTPConfig.instance.doHttpHandle;
			scope(exit) clear();
			if(handle) {
				trace("do handle!");
				try{
					handle(_req,_res);
				} catch {
					mixin(closeChannel("pipeline","this"));
				}
			} else {
				//mixin(closeChannel("pipeline","this"));
				fatal("HTTPConfig.instance.doHttpHandle is null!");
				throw new Exception("HTTPConfig.instance.doHttpHandle is null!");
			}
	}

	bool writeStection(SectionBuffer buffer){
		import std.container.array;
		import core.stdc.string;
		if(buffer.length == 0){
			return false;
		}
		ulong secSize = buffer.stectionSize();
		uint wcount = buffer.writeCount;
		uint wsize = buffer.writeSite;
		Array!(ubyte[]) arbuffer;
		buffer.swap(&arbuffer);
		for(uint i = 0; i < wcount; ++i){
			mixin(writeChannel("pipeline","this","arbuffer[i]"));
		}
		if(wsize < secSize && wsize != 0) {
			ubyte[] data =  arbuffer[wcount][0..wsize];
			mixin(writeChannel("pipeline","this","data"));
		} 
		return true;
	}

	void timeOut(){
		trace("tome out");
		if(_timeOut){
			info("tome out close channel");
			mixin(closeChannel("pipeline","this"));
		}
		_timeOut = true;
	}

	void clear()
	{
		_req.clear();
		_res.clear();
		_writeStection = 0;
		_shouldClose = false;
		if(_frame) _frame.clear();
	}

	void doUpgrade()
	{
		trace(" doUpgrade()");
		import std.string;
		auto header = _req.header();
		string upgrade = header.getHeaderValue("upgrade"); // "upgrade" in header.headerMap();
		string connection =   header.getHeaderValue("connection");//"connection" in header.headerMap();
		string key =  header.getHeaderValue("sec-websocket-key"); //"sec-websocket-key" in header.headerMap();
		//auto pProtocol = "sec-webSocket-protocol" in req.headers;
		string pVersion =  header.getHeaderValue("sec-websocket-version");//"sec-websocket-version" in header.headerMap();
		
		auto isUpgrade = false;

		if( connection.length > 0 ) {
			auto connectionTypes = split(connection, ",");
			foreach( t ; connectionTypes ) {
				if( t.strip().toLower() == "upgrade" ) {
					isUpgrade = true;
					break;
				}
			}
		}
		trace("isUpgrade = ",isUpgrade, "  pVersion = ", pVersion, "   upgrade = ",upgrade);
		if( !(isUpgrade && (icmp(upgrade, "websocket") == 0) && (key.length > 0 ) && (pVersion == "13") ))
		{
			_res.HTTPBody.write(cast(ubyte[])"Browser sent invalid WebSocket request.");
			_res.header.statusCode = 400;
			_shouldClose = true;
			_res.sent();
			return;
		}

		auto accept = cast(string)Base64.encode(sha1Of(key ~ WebSocketGuid));
		auto handle = HTTPConfig.instance.doWebSocket;
		if(handle) {
			_socket = handle(header);
		}
		if(_socket){
			_socket._hand = this;
			switch(pipeline.channel.type) {
				case CHANNEL_TYPE.TCP_Socket:
				{
					auto tcp = cast(TCPSocket)pipeline.channel;
					_socket._addr = tcp.remoteAddress;
				} 
					break;
					version(SSL){
						case CHANNEL_TYPE.SSL_Socket:
						{
							auto tcp = cast(SSLSocket)pipeline.channel;
							_socket._addr = tcp.remoteAddress;
						} 
						break;
					}
				default:
					mixin(closeChannel("pipeline","this"));
					return;
			}
			_frame = new HandleFrame(false);
			_res.header.statusCode = 101;
			_res.header.setHeaderValue("Sec-WebSocket-Accept",accept);
			_res.header.setHeaderValue("Connection","Upgrade");
			_res.header.setHeaderValue("Upgrade","websocket");
			_res.sent();
		} else {
			_res.HTTPBody.write(cast(ubyte[])"Browser sent invalid WebSocket request.");
			_res.header.statusCode = 400;
			_shouldClose = true;
			_res.sent();
		}
		
		//_res.header.setHeaderValue("Sec-WebSocket-Protocol",*pVersion);

	}

	void doFrame(Frame frame, bool text)
	{
		if(frame.isControlFrame){
			switch (frame.opCode()) {
				case OpCode.OpCodePing:
				{//DO pong
					import std.experimental.allocator.mallocator;
					ubyte[] tdata = cast(ubyte[]) Mallocator.instance.allocate(128);
					scope auto buf = new OneBuffer(tdata);
					_frame.pong(tdata,buf);
					_writeStection += 1;
					mixin(writeChannel("pipeline","this","buf.data()"));
				}
					break;
					
				case OpCode.OpCodePong:
					_socket.onPongFrame(frame);
					break;
					
				case OpCode.OpCodeClose:
					mixin(closeChannel("pipeline","this"));
					break;
				default :
					mixin(closeChannel("pipeline","this"));
					break;
			}
		} else {
			if(text){
				_socket.onTextFrame(frame);
			} else {
				_socket.onBinaryFrame(frame);
			}
		}
	}

package:
	bool ping(ubyte[] data)
	{
		if(pipeline.channel.isInValid()) return false;
		import std.experimental.allocator.mallocator;
		ubyte[] tdata = cast(ubyte[]) Mallocator.instance.allocate(128);
		scope auto buf = new OneBuffer(tdata);
		_frame.ping(data,buf);
		_writeStection += 1;
		mixin(writeChannel("pipeline","this","buf.data()"));
		return true;
	}

	bool send(ubyte[] data, bool isBin)
	{ 
		if(pipeline.channel.isInValid()) return false;
		scope auto buffer = new SectionBuffer(HTTPConfig.instance.REP_Body_Stection_Size,threadColliedAllocator);
		_frame.writeFrame(data,isBin,buffer);
		_writeStection += (buffer.writeCount + 1);
		return writeStection(buffer);
	}

	void doClose(){mixin(closeChannel("pipeline","this"));}
private:
	HTTPRequest _req;
	HTTPResponse _res;
	Timer _tm;
	WebSocket _socket = null;
	HandleFrame _frame = null;
	bool _timeOut;
	uint _writeStection = 0;
	bool _shouldClose = false;
};



