module collied.codec.http.request;


import collied.codec.http.header;
import collied.codec.http.parser;
import collied.channel.address;
import collied.codec.http.utils.buffer;
import core.stdc.string : memcpy;
import collied.codec.http.config;
import std.experimental.logger;
import collied.channel.define;

alias CallBackHeader = void delegate (HTTPHeader header);
alias CallBackRequest = void delegate (HTTPRequest header);

class HTTPRequest
{
	this()
	{
		_header = new HTTPHeader(HTTPHeaderType.HTTP_REQUEST);
		_parser = new HTTPParser(HTTPParserType.HTTP_REQUEST);
		_parser.onMessageBegin = &onMessageBegin;
		_parser.onMessageComplete = &onMssageComplete;
		_parser.onUrl = &onURI;
		_parser.onHeaderField = &onHeaderKey;
		_parser.onHeaderValue = &onHeaderValue;
		_parser.onHeaderComplete = &onHeadersComplete;
		_parser.onChunkHeader = &onChunkHeader;
		_parser.onBody = &onBody;
		_parser.onChunkComplete = &onChunkComplete;
		_body = new SectionBuffer(HTTPConfig.instance.REQ_Body_Stection_Size,threadColliedAllocator);
		_addr = Address(0,false);
	}
	~this(){
		_body.destroy;
		_body = null;
		_header.destroy;
		_header = null;
		_parser.destroy;
		_parser = null;
	}

	final @property const(HTTPHeader) header() const {return _header;}
	final @property SectionBuffer HTTPBody(){return _body;}

	final @property Address clientAddress(){return _addr;} 

	final bool parserData(ubyte[] data){
		_dorun = true;
		ulong len = _parser.httpParserExecute(data);
		if((len == data.length || header.upgrade()) && _dorun) {
			if(_headerComplete && fn_headerComplete) fn_headerComplete(_header);
			if(_meassComplete && fn_RequestComplete) fn_RequestComplete(this);
			return true;
		} 
		return false;
	}

	final @property headerComplete(CallBackHeader cback){fn_headerComplete = cback;}
	final @property requestComplete(CallBackRequest cback){fn_RequestComplete = cback;}

package:
	final void clear(){
		_dorun = false;
		_header.clear();
		_body.clear();
		_headerComplete = false;
		_meassComplete = false;
		_parser.rest(HTTPParserType.HTTP_REQUEST);
		_addr = Address(0,false);

	}
	final @property clientAddress(Address addr){_addr = addr;} 

	@property HTTPParser parser(){return _parser;}

	@property isRuning() {return _parser.handleIng;}
protected:
	final void onMessageBegin(HTTPParser)
	{
		trace("HTTPRequest.onMessageBegin");
		if(!_dorun) {_parser.handleIng = false; return;}
		_header.clear();
		_hkey.length = 0;
		_hvalue.length = 0;
		_body.clear();
	}
	
	final void onURI(HTTPParser,ubyte[] data, bool adv)
	{
		trace("HTTPRequest.onURI adv = ", adv," ,url = ", cast(string)data);
		if(!_dorun) {_parser.handleIng = false; return;}
		if(_hkey.length > 0) {
			_hkey ~= data;
		} else {
			_hkey = data.dup;
		}
		if(adv) {
			_header.requestString = cast(string)_hkey;
			_hkey.length = 0;
			_header.method = _parser.methodCode;
		}
	}

	final void onHeaderKey(HTTPParser,ubyte[] data, bool adv)
	{
		trace("HTTPRequest.onHeaderKey adv = ", adv," ,data  = ", cast(string)data);
		if(!_dorun) {_parser.handleIng = false; return;}
			if(_hkey.length > 0) {
				_hkey ~= data;
			} else {
				_hkey = data.dup;
			}
	}
	
	final void onHeaderValue(HTTPParser,ubyte[] data, bool adv)
	{
		trace("HTTPRequest.onHeaderValue adv = ", adv," ,data = ",cast(string)data);
		if(!_dorun) {_parser.handleIng = false; return;}
		if(_hvalue.length > 0) {
			_hvalue ~= data;
		} else {
			_hvalue = data.dup;
		}
		if(adv) {
			_header.setHeaderValue(cast(string)_hkey,cast(string)_hvalue);
			_hkey.length = 0;
			_hvalue.length = 0;
		}
	}
	
	final void  onHeadersComplete(HTTPParser) 
	{
		trace("HTTPRequest.onHeadersComplete");
		if(!_dorun) {_parser.handleIng = false; return;}
		_headerComplete = true;
		_header.upgrade = _parser.isUpgrade;
		if (_parser.major == 1) {
			if(_parser.minor > 0) {
				_header.httpVersion = HTTPVersion.HTTP1_1;
			} else {
				_header.httpVersion = HTTPVersion.HTTP1_0;
			}
		} else if (_parser.major == 2) {
			_header.httpVersion = HTTPVersion.HTTP2;
		}
		if(_header.upgrade) {
			_parser.handleIng = false;
			return;
		}
		trace("HTTPRequest.onHeadersComplete",_parser.contentLength);
	}
	
	final void onBody(HTTPParser,ubyte[] data, bool adv)
	{
		trace("HTTPRequest.onBody adv = ", adv," ,data = ", cast(string)data);
		if(!_dorun) {_parser.handleIng = false; return;}
		_body.write(data);
		if(_body.length > HTTPConfig.instance.Max_Body_Size){
			_parser.handleIng = false;
		}
	}
	
	final void onMssageComplete(HTTPParser)
	{
		trace("HTTPRequest.onMssageComplete");
		if(!_dorun) {_parser.handleIng = false; return;}
		_meassComplete = true;
	}
	
	final void onChunkHeader(HTTPParser)
	{
		trace("HTTPRequest.onChunkHeader");
		if(!_dorun) {_parser.handleIng = false; return;}
	}
	
	final void onChunkComplete(HTTPParser)
	{
		trace("HTTPRequest.onChunkComplete");
		if(!_dorun) {_parser.handleIng = false; return;}
	}

private:
	HTTPHeader _header;
	HTTPParser _parser;
	bool _headerComplete = false;
	bool _meassComplete = false;

	Address _addr;

	CallBackHeader fn_headerComplete;
	CallBackRequest fn_RequestComplete;
	bool _dorun;
private:
	ubyte[] _hkey;
	ubyte[] _hvalue;
	SectionBuffer _body;
}