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
module collie.codec.http.httpmessage;

import collie.codec.http.headers;
import collie.codec.http.exception;

import std.typecons;
import std.typetuple;
import std.socket;
import std.variant;
import std.conv;
import std.exception;
import std.string;
public import std.experimental.logger;

final class HTTPMessage
{
	this()
	{
		_version[0] = 1;
		_version[1] = 1;
	}

	/* Setter and getter for the SPDY priority value (0 - 7).  When serialized
   * to SPDY/2, Codecs will collpase 0,1 -> 0, 2,3 -> 1, etc.
   *
   * Negative values of pri are interpreted much like negative array
   * indexes in python, so -1 will be the largest numerical priority
   * value for this SPDY version (i.e. 3 for SPDY/2 or 7 for SPDY/3),
   * -2 the second largest (i.e. 2 for SPDY/2 or 6 for SPDY/3).
   */
	enum byte kMaxPriority = 7;
	
//	static byte normalizePriority(byte pri) {
//		if (pri > kMaxPriority || pri < -kMaxPriority) {
//			// outside [-7, 7] => highest priority
//			return kMaxPriority;
//		} else if (pri < 0) {
//			return pri + kMaxPriority + 1;
//		}
//		return pri;
//	}

	/**
   * Is this a chunked message? (fpreq, fpresp)
   */
	@property void chunked(bool chunked) { _chunked = chunked; }
	@property bool chunked() const { return _chunked; }

	/**
   * Is this an upgraded message? (fpreq, fpresp)
   */
	@property void upgraded(bool upgraded) { _upgraded = upgraded; }
	@property bool upgraded() const { return _upgraded; }

	/**
   * Set/Get client address
   */
	@property void clientAddress(Address addr) {
		request()._clientAddress = addr;
		request()._clientIP = addr.toAddrString();
		request()._clientPort = addr.toPortString;
	}
	
	@property Address clientAddress() {
		return request()._clientAddress;
	}

	string getClientIP()  {
		return request()._clientIP;
	}
	
	string getClientPort()  {
		return request()._clientPort;
	}

	/**
   * Set/Get destination (vip) address
   */
	@property void dstAddress(Address addr) {
		_dstAddress = addr;
		_dstIP = addr.toAddrString;
		_dstPort = addr.toPortString;
	}
	
	@property Address dstAddress()  {
		return _dstAddress;
	}

	string getDstIP()  {
		return _dstIP;
	}
	
	string getDstPort()  {
		return _dstPort;
	}
	
	/**
   * Set/Get the local IP address
   */
	@property void localIp(string ip) {
		_localIP = ip;
	}
	@property string localIp()  {
		return _localIP;
	}

	@property void method(HTTPMethod method)
	{
		request()._method = method;
	}

	@property HTTPMethod method()
	{
		return request()._method;
	}
	//void setMethod(folly::StringPiece method);

	string methodString(){
		return method_strings[request()._method];
	}

	void setHTTPVersion(ubyte maj, ubyte min)
	{
		_version[0] = maj;
		_version[1] = min;
	}

	auto getHTTPVersion()
	{
		Tuple!(ubyte, "maj", ubyte, "min") tv;
		tv.maj = _version[0];
		tv.min = _version[1];
		return tv;
	}

	@property void url(string url){ 
		auto idx = url.indexOf('?');
		if (idx > 0){
			request()._path = url[0..idx];
			request()._query = url[idx+1..$];
		} else {
			request()._path = url;
		}
		request()._url = url;
	}

	@property string url(){return request()._url;}


	@property wantsKeepAlive(){return _wantsKeepalive;}
	@property wantsKeepAlive(bool klive){_wantsKeepalive = klive;}
	/**
   * Access the path component (fpreq)
   */
	string getPath()
	{
		return request()._path;
	}
	
	/**
   * Access the query component (fpreq)
   */
	string getQueryString()
	{
		return request()._query;
	}

	@property void statusMessage(string msg) {
		response()._statusMsg = msg;
	}
	@property string statusMessage()
	{
		return response()._statusMsg;
	}

	/**
   * Access the status code (fpres)
   */
	@property void statusCode(ushort status)
	{
		response()._status = status;
	}

	@property ushort statusCode()
	{
		return response()._status;
	}

	/**
   * Access the headers (fpreq, fpres)
   */
	ref HTTPHeaders getHeaders(){ return _headers; }

	/**
   * Decrements Max-Forwards header, when present on OPTIONS or TRACE methods.
   *
   * Returns HTTP status code.
   */
	int processMaxForwards()
	{
		auto m = method();
		if (m == HTTPMethod.HTTP_TRACE || m  == HTTPMethod.HTTP_OPTIONS) {
			string value = _headers.getSingleOrEmpty(HTTPHeaderCode.MAX_FORWARDS);
			if (value.length > 0) {
				long max_forwards = -1;

				collectException(to!long(value),max_forwards);

				if (max_forwards < 0) {
					return 400;
				} else if (max_forwards == 0) {
					return 501;
				} else {
					_headers.set(HTTPHeaderCode.MAX_FORWARDS,to!string(max_forwards - 1));
				}
			}
		}
		return 0;
	}
	
	/**
   * Returns true if the version of this message is HTTP/1.0
   */
	bool isHTTP1_0() const
	{
		return _version[0] == 1 && _version[1] == 0;
	}
	
	/**
   * Returns true if the version of this message is HTTP/1.1
   */
	bool isHTTP1_1() const
	{
		return _version[0] == 1 && _version[1] == 1;
	}

	/**
   * Returns true if this is a 1xx response.
   */
	bool is1xxResponse(){ return (statusCode() / 100) == 1; }

	/**
   * Fill in the fields for a response message header that the server will
   * send directly to the client.
   *
   * @param version           HTTP version (major, minor)
   * @param statusCode        HTTP status code to respond with
   * @param msg               textual message to embed in "message" status field
   * @param contentLength     the length of the data to be written out through
   *                          this message
   */
	void constructDirectResponse(ubyte maj,ubyte min,const int statucode,string statusMsg,int contentLength = 0)
	{
		statusCode(cast(ushort)statucode);
		statusMessage(statusMsg);
		constructDirectResponse(maj,min, contentLength);
	}
	
	/**
   * Fill in the fields for a response message header that the server will
   * send directly to the client. This function assumes the status code and
   * status message have already been set on this HTTPMessage object
   *
   * @param version           HTTP version (major, minor)
   * @param contentLength     the length of the data to be written out through
   *                          this message
   */
	void constructDirectResponse(ubyte maj,ubyte min,int contentLength = 0)
	{
		setHTTPVersion(maj,min);
		_headers.set(HTTPHeaderCode.CONTENT_LENGTH,to!string(contentLength));
		if(!_headers.exists(HTTPHeaderCode.CONTENT_TYPE)){
			_headers.add(HTTPHeaderCode.CONTENT_TYPE, "text/plain");
		}
		chunked(false);
		upgraded(false);
	}

	/**
   * Check if query parameter with the specified name exists.
   */
	bool hasQueryParam(string name) 
	{
		parseQueryParams();
		return _queryParams.get(name,string.init) != string.init;
	}
	/**
   * Get the query parameter with the specified name.
   *
   * Returns a reference to the query parameter value, or
   * proxygen::empty_string if there is no parameter with the
   * specified name.  The returned value is only valid as long as this
   * HTTPMessage object.
   */
	string getQueryParam(string name)
	{
		parseQueryParams();
		return _queryParams.get(name,string.init);
	}
	/**
   * Get the query parameter with the specified name after percent decoding.
   *
   * Returns empty string if parameter is missing or folly::uriUnescape
   * query param
   */
	string getDecodedQueryParam(string name)
	{
		import std.uri;
		parseQueryParams();
		string v = _queryParams.get(name,string.init);
		if(v == string.init)
			return v;
		return decodeComponent(v);
	}

	/**
   * Get the query parameter with the specified name after percent decoding.
   *
   * Returns empty string if parameter is missing or folly::uriUnescape
   * query param
   */
	string[string] queryParam(){parseQueryParams();return _queryParams;}

	/**
   * Set the query string to the specified value, and recreate the url_.
   *
   */
	void setQueryString(string query)
	{
		unparseQueryParams();
		request._query = query;
	}
	/**
   * Remove the query parameter with the specified name.
   *
   */
	void removeQueryParam(string name)
	{
		parseQueryParams();
		_queryParams.remove(name);
	}
	
	/**
   * Sets the query parameter with the specified name to the specified value.
   *
   * Returns true if the query parameter was successfully set.
   */
	void setQueryParam(string name, string value)
	{
		parseQueryParams();
		_queryParams[name] = value;
	}


	/**
   * @returns true if this HTTPMessage represents an HTTP request
   */
	bool isRequest() const {
		return _isRequest == MegType.Request_;
	}
	
	/**
   * @returns true if this HTTPMessage represents an HTTP response
   */
	bool isResponse() const {
		return _isRequest == MegType.Response_;
	}

	static string statusText(int code)
	{
		switch (code)
		{
			case 100:
				return "Continue";
			case 101:
				return "Switching Protocols";
			case 102:
				return "Processing"; // RFC2518
			case 200:
				return "OK";
			case 201:
				return "Created";
			case 202:
				return "Accepted";
			case 203:
				return "Non-Authoritative Information";
			case 204:
				return "No Content";
			case 205:
				return "Reset Content";
			case 206:
				return "Partial Content";
			case 207:
				return "Multi-Status"; // RFC4918
			case 208:
				return "Already Reported"; // RFC5842
			case 226:
				return "IM Used"; // RFC3229
			case 300:
				return "Multiple Choices";
			case 301:
				return "Moved Permanently";
			case 302:
				return "Found";
			case 303:
				return "See Other";
			case 304:
				return "Not Modified";
			case 305:
				return "Use Proxy";
			case 306:
				return "Reserved";
			case 307:
				return "Temporary Redirect";
			case 308:
				return "Permanent Redirect"; // RFC7238
			case 400:
				return "Bad Request";
			case 401:
				return "Unauthorized";
			case 402:
				return "Payment Required";
			case 403:
				return "Forbidden";
			case 404:
				return "Not Found";
			case 405:
				return "Method Not Allowed";
			case 406:
				return "Not Acceptable";
			case 407:
				return "Proxy Authentication Required";
			case 408:
				return "Request Timeout";
			case 409:
				return "Conflict";
			case 410:
				return "Gone";
			case 411:
				return "Length Required";
			case 412:
				return "Precondition Failed";
			case 413:
				return "Request Entity Too Large";
			case 414:
				return "Request-URI Too Long";
			case 415:
				return "Unsupported Media Type";
			case 416:
				return "Requested Range Not Satisfiable";
			case 417:
				return "Expectation Failed";
			case 418:
				return "I\"m a teapot"; // RFC2324
			case 422:
				return "Unprocessable Entity"; // RFC4918
			case 423:
				return "Locked"; // RFC4918
			case 424:
				return "Failed Dependency"; // RFC4918
			case 425:
				return "Reserved for WebDAV advanced collections expired proposal"; // RFC2817
			case 426:
				return "Upgrade Required"; // RFC2817
			case 428:
				return "Precondition Required"; // RFC6585
			case 429:
				return "Too Many Requests"; // RFC6585
			case 431:
				return "Request Header Fields Too Large"; // RFC6585
			case 500:
				return "Internal Server Error";
			case 501:
				return "Not Implemented";
			case 502:
				return "Bad Gateway";
			case 503:
				return "Service Unavailable";
			case 504:
				return "Gateway Timeout";
			case 505:
				return "HTTP Version Not Supported";
			case 506:
				return "Variant Also Negotiates (Experimental)"; // RFC2295
			case 507:
				return "Insufficient Storage"; // RFC4918
			case 508:
				return "Loop Detected"; // RFC5842
			case 510:
				return "Not Extended"; // RFC2774
			case 511:
				return "Network Authentication Required"; // RFC6585
			default:
				return "  ";
		}
	}

protected:
	/** The 12 standard fields for HTTP messages. Use accessors.
   * An HTTPMessage is either a Request or Response.
   * Once an accessor for either is used, that fixes the type of HTTPMessage.
   * If an access is then used for the other type, a DCHECK will fail.
   */
	struct Request 
	{
		Address _clientAddress;
		string _clientIP;
		string _clientPort;
		HTTPMethod _method = HTTPMethod.HTTP_INVAILD;
		string _path;
		string _query;
		string _url;
			
		//ushort _pushStatus;
		//string _pushStatusStr;
	}
	
	struct Response 
	{
		ushort _status = 200;
		string _statusStr;
		string _statusMsg;
	}

	ref Request request() 
	{
		if(_isRequest == MegType.Null_) {
			_isRequest = MegType.Request_;
			_resreq.req = Request();
		} else if(_isRequest == MegType.Response_){
			throw new HTTPMessageTypeException("the message type is Response not Request");
		}
		return _resreq.req;
	}

	ref Response response()
	{
		if(_isRequest == MegType.Null_) {
			_isRequest = MegType.Response_;
			_resreq.res = Response();
		} else if(_isRequest == MegType.Request_){
			throw new HTTPMessageTypeException("the message type is Request not Response");
		}

		return _resreq.res;
	}

protected:
	//void parseCookies(){}
	
	void parseQueryParams(){
		import collie.utils.string;
		if(_parsedQueryParams) return;
		_parsedQueryParams = true;
		string query = getQueryString();
		if(query.length == 0) return;
		splitNameValue(query, '&', '=',(string name,string value){
				name = strip(name);
				value = strip(value);
				_queryParams[name] = value;
				return true;
			});
	}
	void unparseQueryParams(){
		_queryParams.clear();
		_parsedQueryParams = false;
	}

	union Req_Res
	{
		Request req;
		Response res;
	}

	enum MegType : ubyte{
		Null_,
		Request_,
		Response_,
	}

private:
	Address _dstAddress;
	string _dstIP;
	string _dstPort;
		
	string _localIP;
	string _versionStr;
	MegType _isRequest = MegType.Null_;
	Req_Res _resreq;
private:
	ubyte[2] _version;
	HTTPHeaders _headers;
//	string[string] _cookies;
	string[string] _queryParams;

private:
	bool _parsedCookies = false;
	bool _parsedQueryParams = false;
	bool _chunked = false;
	bool _upgraded = false;
	bool _wantsKeepalive = true;
}

