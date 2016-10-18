module collie.codec.http.codec.http1xcodec;

import collie.codec.http.codec.httpcodec;
import collie.codec.http.parser;
import collie.codec.http.httptansaction;
import collie.codec.http.httpmessage;
import collie.codec.http.headers;
import collie.utils.vector;
import std.experimental.allocator.gc_allocator;
import std.conv;
import std.array;

class HTTP1XCodec : HTTPCodec
{
	alias HVector = Vector!(ubyte,GCAllocator);

	this(TransportDirection direction, uint maxHeaderSize = (64 * 1024))
	{
		_transportDirection = direction;
		_finished = true;
		_maxHeaderSize = maxHeaderSize;
		if(_transportDirection = TransportDirection.DOWNSTREAM){
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
			return ++ingressTxnID_;
		} else {
			return ++egressTxnID_;
		}
	}

	override bool isBusy() {
		return !_finished;
	}

	override void setParserPaused(bool paused){}

	override void setCallback(CallBack callback) {
		_callback = callback;
	}

	override size_t onIngress(ubyte[] buf)
	{
		auto size = _parser.httpParserExecute(buf);
		if(size != buf.length && _parser.isUpgrade == false){
			_callback.onError(0,"");
		}
		return cast(size_t) size;
	}

	override size_t generateHeader(StreamID stream,HTTPMessage msg,ref HVector buffer,bool eom = false)
	{
		const bool upstream = (transportDirection_ == TransportDirection.UPSTREAM);
		auto hversion = msg.getHTTPVersion();
		Appender!string data = appender!string;
		_egressChunked = msg.chunked && !_egressUpgrade;
		_lastChunkWritten = false;
		bool hasTransferEncodingChunked = false;
		bool hasUpgradeHeader = false;
		bool hasDateHeader = false;
		if(!upstream) {
			data.put("HTTP/");
			data.put(to!string(hversion.maj));
			data.put(".");
			data.put(to!string(hversion.min));
			data.put(" ");
			int code = msg.statusCode;
			data.put(to!string(code));
			data.put(" ");
			data.put(HTTPMessage.statusText(code));
		} else {
			data.put(msg.methodString);
			data.put(" ");
			data.put(msg.getPath);
			data.put(" HTTP/");
			data.put(to!string(hversion.maj));
			data.put(".");
			data.put(to!string(hversion.min));
			_mayChunkEgress = msg.isHTTP1_1();
		}
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
			data.put(key);
			data.put(": ");
			data.put(value);
			data.put("\r\n");
		}
		_inChunk = false;
		bool bodyCheck =
			(!upstream && !_egressUpgrade) ||
				// auto chunk POSTs and any request that came to us chunked
				(upstream && ((msg.method == HTTPMethod.POST) || _egressChunked));
		// TODO: 400 a 1.0 POST with no content-length
		// clear egressChunked_ if the header wasn't actually set
		_egressChunked &= hasTransferEncodingChunked;
		if(bodyCheck && contLen.length == 0 && _egressChunked){
			data.put("Transfer-Encoding: chunked\r\n");
		}
		if(upstream || hasUpgradeHeader){
			data.put("Connection: ");
			if(hasUpgradeHeader)
				data.put("upgrade\r\n");
			if(_keepalive)
				data.put("keep-alive\r\n");
			else
				data.put("close\r\n");
		}
		if(contLen.length > 0){
			data.put("Content-Length: ");;
			data.put(contLen);
			data.put("\r\n");
		}

		data.put("\r\n");
	}

	ubyte[] generateBody(StreamID stream,
		ubyte[] chain,
		bool eom)
	{
		if(_egressChunked && !_inChunk) {

		}
	}

	ubyte[] generateChunkHeader(
		StreamID stream,
		size_t length)
	{
		if (_egressChunked){
			import std.format;
			_inChunk = true;
			string lent = format("%zx\r\n",length);
			return cast(ubyte[])lent;
		}
		return ubyte[].init;
	}


	ubyte[] generateChunkTerminator(
		StreamID stream)
	{
		if(_egressChunked && _inChunk)
		{
			_inChunk = false;
			return cast(ubyte[])("\r\n".dup);
		}
		return ubyte[].init;
	}

	ubyte[] generateEOM(StreamID stream)
	{
		ubyte[] data;
		assert(stream == _egressTxnID);
		if(_egressChunked) {
			assert(!_inChunk);
			if(!_lastChunkWritten)
				_lastChunkWritten = true;
			data = cast(ubyte[])("0\r\n".dup);
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
		return data;
	}

	ubyte[] generateRstStream(StreamID stream,HTTPErrorCode code)
	{}
protected:
	void onMessageBegin(ref HTTPParser){
		_finished = false;
		_headersComplete = false;
		_message = new HTTPMessage();
		if (transportDirection_ == TransportDirection.DOWNSTREAM) {
			_requestPending = true;
			_responsePending = true;
		}
		// If there was a 1xx on this connection, don't increment the ingress txn id
		if (_transportDirection == TransportDirection.DOWNSTREAM ||
			!_is1xxResponse) {
			++_ingressTxnID;
		}
		if (transportDirection_ == TransportDirection.UPSTREAM) {
			_is1xxResponse = false;
		}
		_callback->onMessageBegin(_ingressTxnID, _message);
		_currtKey.clear();
		_currtValue.clear();
	}
	
	void onHeadersComplete(ref HTTPParser parser){
		_mayChunkEgress = ((parser.major == 1) && (parser.major >= 1));
		_message.setHTTPVersion(cast(ubyte)parser.major, cast(ubyte)parser.minor);
		_egressUpgrade = parser.isUpgrade;
		_message.upgraded(parser.isUpgrade);
		int klive = parser.keepalive;
		switch(klive){
			case 1:
				_keepalive = false;
				break;
			case 2:
				_keepalive = true;
				break;
			default :
				_keepalive = false;
		}
		_message.wantsKeepAlive(_keepalive);
		_headersComplete = true;
		_callback.onHeadersComplete(_ingressTxnID,_message);

	}
	
	void onMessageComplete(ref HTTPParser parser){
		switch (transportDirection_) {
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
		if(_transportDirection = TransportDirection.DOWNSTREAM){
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
		_currtKey.insertBack(data);
		if(finish) {
			ubyte[] data = _currtKey.data(true);
			_message.url = cast(string)data;
		}
	}
	
	void onStatus(ref HTTPParser parser, ubyte[] data, bool finish)
	{
		_currtKey.insertBack(data);
		if(finish) {
			string sdata = cast(string)_currtKey.data(true);
			_message.setStatusCode(cast(ushort)parser.statusCode);
			_message.statusMessage(sdata);
		}
	}
	
	void onHeaderField(ref HTTPParser parser, ubyte[] data, bool finish)
	{
		_currtKey.insertBack(data);
	}
	
	void onHeaderValue(ref HTTPParser parser, ubyte[] data, bool finish)
	{
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
	HeaderParseState _headerParseState;
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

