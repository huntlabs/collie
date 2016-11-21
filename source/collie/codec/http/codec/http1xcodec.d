module collie.codec.http.codec.http1xcodec;

import collie.codec.http.codec.httpcodec;
import collie.codec.http.errocode;
import collie.codec.http.headers;
import collie.codec.http.httpmessage;
import collie.codec.http.httptansaction;
import collie.codec.http.parser;
import std.array;
import std.conv;
import std.traits;

class HTTP1XCodec : HTTPCodec
{
	this(TransportDirection direction, uint maxHeaderSize = (64 * 1024))
	{
		_transportDirection = direction;
		_finished = true;
		_maxHeaderSize = maxHeaderSize;
		if(_transportDirection == TransportDirection.DOWNSTREAM){
			_parser = HTTPParser(HTTPParserType.HTTP_REQUEST,_maxHeaderSize);
		}else {
			_parser = HTTPParser(HTTPParserType.HTTP_RESPONSE,_maxHeaderSize);
		}
		_parser.onUrl(&onUrl);
		_parser.onMessageBegin(&onMessageBegin);
		_parser.onHeaderComplete(&onHeadersComplete);
		_parser.onHeaderField(&onHeaderField);
		_parser.onHeaderValue(&onHeaderValue);
		_parser.onStatus(&onStatus);
		_parser.onChunkHeader(&onChunkHeader);
		_parser.onChunkComplete(&onChunkComplete);
		_parser.onBody(&onBody);
		_parser.onMessageComplete(&onMessageComplete);
	}

	override CodecProtocol getProtocol() {
		return CodecProtocol.HTTP_1_X;
	}

	override TransportDirection getTransportDirection()
	{
		return _transportDirection;
	}

	override StreamID createStream() {
		if (_transportDirection == TransportDirection.DOWNSTREAM) {
			return ++_ingressTxnID;
		} else {
			return ++_egressTxnID;
		}
	}

	override bool isBusy() {
		return !_finished;
	}

	override bool shouldClose()
	{
		return !_keepalive;
	}

	override void setParserPaused(bool paused){}

	override void setCallback(CallBack callback) {
		_callback = callback;
	}

	override size_t onIngress(ubyte[] buf)
	{
		auto size = _parser.httpParserExecute(buf);
		if(size != buf.length && _parser.isUpgrade == false){
			_callback.onError(_ingressTxnID,HTTPErrorCode.PROTOCOL_ERROR);
		}
		return cast(size_t) size;
	}

	override size_t generateHeader(
		StreamID stream,
		HTTPMessage msg,
		ref HVector buffer,
		bool eom = false)
	{
		const bool upstream = (_transportDirection == TransportDirection.UPSTREAM);
		const size_t beforLen = buffer.length;
		auto hversion = msg.getHTTPVersion();
		_egressChunked = msg.chunked && !_egressUpgrade;
		_lastChunkWritten = false;
		bool hasTransferEncodingChunked = false;
		bool hasUpgradeHeader = false;
		bool hasDateHeader = false;
		bool is1xxResponse = false;
		_keepalive = _keepalive & msg.wantsKeepAlive;
		if(!upstream) {
			is1xxResponse = msg.is1xxResponse;
			appendLiteral(buffer,"HTTP/");
			appendLiteral(buffer,to!string(hversion.maj));
			appendLiteral(buffer,".");
			appendLiteral(buffer,to!string(hversion.min));
			appendLiteral(buffer," ");
			int code = msg.statusCode;
			appendLiteral(buffer,to!string(code));
			appendLiteral(buffer," ");
			appendLiteral(buffer,msg.statusMessage);
		} else {
			appendLiteral(buffer,msg.methodString);
			appendLiteral(buffer," ");
			appendLiteral(buffer,msg.getPath);
			appendLiteral(buffer," HTTP/");
			appendLiteral(buffer,to!string(hversion.maj));
			appendLiteral(buffer,".");
			appendLiteral(buffer,to!string(hversion.min));
			_mayChunkEgress = msg.isHTTP1_1();
		}
		appendLiteral(buffer,"\r\n");
		_egressChunked &= _mayChunkEgress;
		string contLen;
		string upgradeHeader;
		foreach(HTTPHeaderCode code,string key,string value; msg.getHeaders)
		{
			if(code == HTTPHeaderCode.CONTENT_LENGTH){
				contLen = value;
				continue;
			} else if (code ==  HTTPHeaderCode.CONNECTION) {
				if(isSame(value,"close")) {
					_keepalive = false;
				}
				continue;
			} else if(code == HTTPHeaderCode.UPGRADE){
				if(upstream) upgradeHeader = value;
				hasUpgradeHeader = true;
			}  else if (!hasTransferEncodingChunked &&
				code == HTTPHeaderCode.TRANSFER_ENCODING) {
				if(!isSame(value,"chunked")) 
					continue;
				hasTransferEncodingChunked = true;
				if(!_mayChunkEgress) continue;
			} 
			appendLiteral(buffer,key);
			appendLiteral(buffer,": ");
			appendLiteral(buffer,value);
			appendLiteral(buffer,"\r\n");
		}
		_inChunk = false;
		bool bodyCheck =
			(!upstream && !_egressUpgrade) ||
				// auto chunk POSTs and any request that came to us chunked
				(upstream && ((msg.method == HTTPMethod.HTTP_POST) || _egressChunked));
		// TODO: 400 a 1.0 POST with no content-length
		// clear egressChunked_ if the header wasn't actually set
		_egressChunked &= hasTransferEncodingChunked;
		if(bodyCheck && contLen.length == 0 && _egressChunked){
			appendLiteral(buffer,"Transfer-Encoding: chunked\r\n");
		}
		if(!is1xxResponse || upstream || hasUpgradeHeader){
			appendLiteral(buffer,"Connection: ");
			if(hasUpgradeHeader) {
				appendLiteral(buffer,"upgrade\r\n");
				_keepalive = true;
			} else if(_keepalive)
				appendLiteral(buffer,"keep-alive\r\n");
			else
				appendLiteral(buffer,"close\r\n");
		}
		if(contLen.length > 0){
			appendLiteral(buffer,"Content-Length: ");
			appendLiteral(buffer,contLen);
			appendLiteral(buffer,"\r\n");
		}

		appendLiteral(buffer,"\r\n");
		return buffer.length - beforLen;
	}

	override size_t generateBody(StreamID stream,
		ref HVector chain,
		bool eom)
	{
		size_t rlen = 0;
		if(_egressChunked && !_inChunk) {
			appendLiteral(chain,"\r\n");
			rlen += 2;
		}
		if(eom)
			rlen += generateEOM(stream,chain);
		return rlen;
	}

	override size_t generateChunkHeader(
		StreamID stream,
		ref HVector buffer,
		size_t length)
	{
		if (_egressChunked){
			import std.format;
			_inChunk = true;
			string lent = format("%zx\r\n",length);
			appendLiteral(buffer,lent);
			return lent.length;
		}
		return 0;
	}


	override size_t generateChunkTerminator(
		StreamID stream,
		ref HVector buffer)
	{
		if(_egressChunked && _inChunk)
		{
			_inChunk = false;
			appendLiteral(buffer,"\r\n");
			return 2;
		}
		return 0;
	}

	override size_t generateEOM(StreamID stream,
		ref HVector buffer)
	{
		size_t rlen = 0;
		//assert(stream == _egressTxnID);
		if(_egressChunked) {
			assert(!_inChunk);
			if(!_lastChunkWritten)
				_lastChunkWritten = true;
			appendLiteral(buffer,"0\r\n");
			rlen += 3;
		}
		switch (_transportDirection) {
			case TransportDirection.DOWNSTREAM:
				_responsePending = false;
				break;
			case TransportDirection.UPSTREAM:
				_requestPending = false;
				break;
			default:
				break;
		}
		return rlen;
	}

	override size_t  generateRstStream(StreamID stream,
		ref HVector buffer,HTTPErrorCode code)
	{
		return 0;
	}
protected:

	final void appendLiteral(T)(ref HVector buffer, T[] data) if(isSomeChar!(Unqual!T) || is(Unqual!T == byte) || is(Unqual!T == ubyte))
	{
		buffer.insertBack(cast(ubyte[])data);
	}

	void onMessageBegin(ref HTTPParser){
		_finished = false;
		_headersComplete = false;
		_message = new HTTPMessage();
		if (_transportDirection == TransportDirection.DOWNSTREAM) {
			_requestPending = true;
			_responsePending = true;
		}
		// If there was a 1xx on this connection, don't increment the ingress txn id
		if (_transportDirection == TransportDirection.DOWNSTREAM ||
			!_is1xxResponse) {
			++_ingressTxnID;
		}
		if (_transportDirection == TransportDirection.UPSTREAM) {
			_is1xxResponse = false;
		}
		_callback.onMessageBegin(_ingressTxnID, _message);
		_currtKey.clear();
		_currtValue.clear();
	}
	
	void onHeadersComplete(ref HTTPParser parser){
		_mayChunkEgress = ((parser.major == 1) && (parser.major >= 1));
		_message.setHTTPVersion(cast(ubyte)parser.major, cast(ubyte)parser.minor);
		_egressUpgrade = parser.isUpgrade;
		_message.upgraded(parser.isUpgrade);
		int klive = parser.keepalive;
		trace("++++++++++klive : ", klive);
		switch(klive){
			case 1:
				_keepalive = true;
				break;
			case 2:
				_keepalive = false;
				break;
			default :
				_keepalive = false;
		}
		_message.wantsKeepAlive(_keepalive);
		_headersComplete = true;
		if(_message.upgraded){
			string upstring  = _message.getHeaders.getSingleOrEmpty(HTTPHeaderCode.UPGRADE);
			CodecProtocol pro = getProtocol(upstring);
			_callback.onNativeProtocolUpgrade(_ingressTxnID,pro,upstring,_message);
		} else {
			_callback.onHeadersComplete(_ingressTxnID,_message);
		}
	}
	
	void onMessageComplete(ref HTTPParser parser){
		switch (_transportDirection) {
			case TransportDirection.DOWNSTREAM:
			{
				_requestPending = false;
				// else there was no match, OR we upgraded to http/1.1 OR someone specified
				// a non-native protocol in the setAllowedUpgradeProtocols.  No-ops
				break;
			}
			case TransportDirection.UPSTREAM:
				_responsePending = _is1xxResponse;
				break;
			default: break;
		}
		_callback.onMessageComplete(_ingressTxnID,parser.isUpgrade);
		if(_transportDirection == TransportDirection.DOWNSTREAM){
			_parser.rest(HTTPParserType.HTTP_REQUEST,_maxHeaderSize);
		}else {
			_parser.rest(HTTPParserType.HTTP_RESPONSE,_maxHeaderSize);
		}
	}
	
	void onChunkHeader(ref HTTPParser parser){
		_callback.onChunkHeader(_ingressTxnID,cast(size_t)parser.contentLength);
	}
	
	void onChunkComplete(ref HTTPParser parser){
		_callback.onChunkComplete(_ingressTxnID);
	}
	
	void onUrl(ref HTTPParser parser, ubyte[] data, bool finish)
	{
		//trace("on Url");
		_message.method = parser.methodCode();
		_currtKey.insertBack(data);
		if(finish) {
			ubyte[] tdata = _currtKey.data(true);
			_message.url = cast(string)tdata;
		}
	}
	
	void onStatus(ref HTTPParser parser, ubyte[] data, bool finish)
	{

		_currtKey.insertBack(data);
		if(finish) {
			string sdata = cast(string)_currtKey.data(true);
			_message.statusCode(cast(ushort)parser.statusCode);
			_message.statusMessage(sdata);
		}
	}
	
	void onHeaderField(ref HTTPParser parser, ubyte[] data, bool finish)
	{
		//trace("on onHeaderField");
		_currtKey.insertBack(data);
	}
	
	void onHeaderValue(ref HTTPParser parser, ubyte[] data, bool finish)
	{
	//	trace("on onHeaderField");
		_currtValue.insertBack(data);
		if(finish){
			string key = cast(string)_currtKey.data(true);
			string value = cast(string)_currtValue.data(true);
			_message.getHeaders.add(key,value);
		}
	}
	
	void onBody(ref HTTPParser parser, ubyte[] data, bool finish)
	{
		_callback.onBody(_ingressTxnID,data);
	}
private:
	TransportDirection _transportDirection;
	CallBack _callback;
	StreamID _ingressTxnID;
	StreamID _egressTxnID;
	HTTPMessage _message;
	HVector _currtKey;
	HVector _currtValue;
	HTTPParser _parser;

	uint _maxHeaderSize;
	bool _finished;
private:
	bool _parserActive = false;
	bool _pendingEOF = false;
	bool _parserPaused = false;
	bool _parserError = false;
	bool _requestPending = false;
	bool _responsePending = false;
	bool _egressChunked = false;
	bool _inChunk = false;
	bool _lastChunkWritten = false;
	bool _keepalive = false;
	bool _disableKeepalivePending = false;
	bool _connectRequest = false;
	bool _headRequest = false;
	bool _expectNoResponseBody = false;
	bool _mayChunkEgress = false;
	bool _is1xxResponse = false;
	bool _inRecvLastChunk = false;
	bool _ingressUpgrade = false;
	bool _ingressUpgradeComplete = false;
	bool _egressUpgrade = false;
	bool _nativeUpgrade = false;
	bool _headersComplete = false;
}

