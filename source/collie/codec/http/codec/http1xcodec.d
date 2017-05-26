/*
 * Collie - An asynchronous event-driven network framework using Dlang development
 *
 * Copyright (C) 2015-2017  Shanghai Putao Technology Co., Ltd 
 *
 * Developer: putao's Dlang team
 *
 * Licensed under the Apache-2.0 License.
 *
 */
module collie.codec.http.codec.http1xcodec;

import collie.codec.http.codec.httpcodec;
import collie.codec.http.errocode;
import collie.codec.http.headers;
import collie.codec.http.httpmessage;
import collie.codec.http.httptansaction;
import collie.codec.http.parser;
import collie.utils.string;
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
		_currtKey = HVector(256);
		_currtValue = HVector(256);
	}

	override CodecProtocol getProtocol() {
		return CodecProtocol.HTTP_1_X;
	}

	override TransportDirection getTransportDirection()
	{
		return _transportDirection;
	}

	override StreamID createStream() {
		return 0;
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
		trace("on Ingress!!");
		if(_finished) {
			_parser.rest(HTTPParserType.HTTP_BOTH,_maxHeaderSize);
		}
		auto size = _parser.httpParserExecute(buf);
		if(size != buf.length && _parser.isUpgrade == false && _transaction && _callback){
				_callback.onError(_transaction,HTTPErrorCode.PROTOCOL_ERROR);
		}
		return cast(size_t) size;
	}

	override void onConnectClose()
	{
		if(_transaction){
			_transaction.onErro(HTTPErrorCode.REMOTE_CLOSED);
			_transaction.handler = null;
			_transaction.transport = null;
			_transaction = null;
		}
	}

	override void onTimeOut()
	{
		if(_transaction){
			_transaction.onErro(HTTPErrorCode.TIME_OUT);
		}
	}

	override void detach(HTTPTransaction txn)
	{
		if(txn is _transaction)
			_transaction = null;
	}

	override size_t generateHeader(
		HTTPTransaction txn,
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
		bool ingorebody = false;
		_keepalive = _keepalive & msg.wantsKeepAlive;
		if(!upstream) {
			is1xxResponse = msg.is1xxResponse;
			appendLiteral(buffer,"HTTP/");
			appendLiteral(buffer,to!string(hversion.maj));
			appendLiteral(buffer,".");
			appendLiteral(buffer,to!string(hversion.min));
			appendLiteral(buffer," ");
			ushort code = msg.statusCode;
			ingorebody = responseBodyMustBeEmpty(code);
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
			_mayChunkEgress = (hversion.maj == 1) && (hversion.min >= 1);
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
				if(isSameIngnoreLowUp(value,"close")) {
					_keepalive = false;
				}
				continue;
			} else if(code == HTTPHeaderCode.UPGRADE){
				if(upstream) upgradeHeader = value;
				hasUpgradeHeader = true;
			}  else if (!hasTransferEncodingChunked &&
				code == HTTPHeaderCode.TRANSFER_ENCODING) {
				if(!isSameIngnoreLowUp(value,"chunked")) 
					continue;
				hasTransferEncodingChunked = true;
				if(!_mayChunkEgress) 
					continue;
			} 
			appendLiteral(buffer,key);
			appendLiteral(buffer,": ");
			appendLiteral(buffer,value);
			appendLiteral(buffer,"\r\n");
		}
		_inChunk = false;
		bool bodyCheck = ((!upstream) && _keepalive && !ingorebody  && !_egressUpgrade) ||
				// auto chunk POSTs and any request that came to us chunked
				(upstream && ((msg.method == HTTPMethod.HTTP_POST) || _egressChunked));
		// TODO: 400 a 1.0 POST with no content-length
		// clear egressChunked_ if the header wasn't actually set
		_egressChunked &= hasTransferEncodingChunked;
		if(bodyCheck && contLen.length == 0 && !_egressChunked){
			if (!hasTransferEncodingChunked && _mayChunkEgress) {
				appendLiteral(buffer,"Transfer-Encoding: chunked\r\n");
				_egressChunked = true;
			} else {
				_keepalive = false;
			}
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
		appendLiteral(buffer,"Server: Collie\r\n");
		if(contLen.length > 0){
			appendLiteral(buffer,"Content-Length: ");
			appendLiteral(buffer,contLen);
			appendLiteral(buffer,"\r\n");
		}

		appendLiteral(buffer,"\r\n");
		return buffer.length - beforLen;
	}

	override size_t generateBody(HTTPTransaction txn,
		ref HVector chain,
		bool eom)
	{
		size_t rlen = 0;
		if(_egressChunked && _inChunk) {
			appendLiteral(chain,"\r\n");
			_inChunk = false;
			rlen += 2;
		}
		if(eom)
			rlen += generateEOM(txn,chain);
		return rlen;
	}

	override size_t generateChunkHeader(
		HTTPTransaction txn,
		ref HVector buffer,
		size_t length)
	{
		trace("_egressChunked  ", _egressChunked);
		if (_egressChunked){
			import std.format;
			_inChunk = true;
			string lent = format("%x\r\n",length);
			trace("length is : ", length, "  x is: ", lent);
			appendLiteral(buffer,lent);
			return lent.length;
		}
		return 0;
	}


	override size_t generateChunkTerminator(
		HTTPTransaction txn,
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

	override size_t generateEOM(HTTPTransaction txn,
		ref HVector buffer)
	{
		size_t rlen = 0;
		if(_egressChunked) {
			assert(!_inChunk);
			if (_headRequest && _transportDirection == TransportDirection.DOWNSTREAM) {
				_lastChunkWritten = true;
			} else {
				// appending a 0\r\n only if it's not a HEAD and downstream request
				if (!_lastChunkWritten) {
					_lastChunkWritten = true;
					//if (!(_headRequest &&
					//		transportDirection_ == TransportDirection.DOWNSTREAM)) {
					appendLiteral(buffer,"0\r\n");
					rlen += 3;
					//}
				}
				appendLiteral(buffer,"\r\n");
			}
			rlen += 2;
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

	override size_t  generateRstStream(HTTPTransaction txn,
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
		}
		if (_transportDirection == TransportDirection.UPSTREAM) {
			_is1xxResponse = false;
		}
		_transaction = new HTTPTransaction(_transportDirection,0,0);
		if(_callback)
			_callback.onMessageBegin(_transaction, _message);
		_currtKey.clear();
		_currtValue.clear();
	}
	
	void onHeadersComplete(ref HTTPParser parser){
		_mayChunkEgress = ((parser.major == 1) && (parser.minor >= 1));
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
			CodecProtocol pro = getProtocolFormString(upstring);
			if(_callback)
				_callback.onNativeProtocolUpgrade(_transaction,pro,upstring,_message);
		} else {
			if(_callback)
				_callback.onHeadersComplete(_transaction,_message);
		}
	}
	
	void onMessageComplete(ref HTTPParser parser){
		_finished = true;
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
		if(_callback)
			_callback.onMessageComplete(_transaction,parser.isUpgrade);
	}
	
	void onChunkHeader(ref HTTPParser parser){
		if(_callback)
			_callback.onChunkHeader(_transaction,cast(size_t)parser.contentLength);
	}
	
	void onChunkComplete(ref HTTPParser parser){
		if(_callback)
			_callback.onChunkComplete(_transaction);
	}
	
	void onUrl(ref HTTPParser parser, ubyte[] data, bool finish)
	{
		//trace("on Url");
		_message.method = parser.methodCode();
		_connectRequest = (parser.methodCode() == HTTPMethod.HTTP_CONNECT);
		
		// If this is a headers-only request, we shouldn't send
		// an entity-body in the response.
		_headRequest = (parser.methodCode() == HTTPMethod.HTTP_HEAD);

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
			trace("http header: \t", key, " : ", value);
			_message.getHeaders.add(key,value);
		}
	}
	
	void onBody(ref HTTPParser parser, ubyte[] data, bool finish)
	{
		trace("on boday, length : ", data.length);
		_callback.onBody(_transaction,data);
	}

	bool responseBodyMustBeEmpty(ushort status) {
		return (status == 304 || status == 204 ||
			(100 <= status && status < 200));
	}
private:
	TransportDirection _transportDirection;
	CallBack _callback;
	HTTPTransaction _transaction;
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

