module collie.codec.http.httpmessage;

import collie.codec.http.headers;

import std.typecons;
import std.typetuple;
import std.socket;
import std.variant;
import std.conv;
import std.exception;
import std.string;

class HTTPMessage
{
	this()
	{}

	/* Setter and getter for the SPDY priority value (0 - 7).  When serialized
   * to SPDY/2, Codecs will collpase 0,1 -> 0, 2,3 -> 1, etc.
   *
   * Negative values of pri are interpreted much like negative array
   * indexes in python, so -1 will be the largest numerical priority
   * value for this SPDY version (i.e. 3 for SPDY/2 or 7 for SPDY/3),
   * -2 the second largest (i.e. 2 for SPDY/2 or 6 for SPDY/3).
   */
	enum byte kMaxPriority = 7;
	
	static byte normalizePriority(byte pri) {
		if (pri > kMaxPriority || pri < -kMaxPriority) {
			// outside [-7, 7] => highest priority
			return kMaxPriority;
		} else if (pri < 0) {
			return pri + kMaxPriority + 1;
		}
		return pri;
	}

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
	
	@property Address clientAddress() const {
		return request()._clientAddress;
	}

	string getClientIP() const {
		return request()._clientIP;
	}
	
	string getClientPort() const {
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
	
	@property Address dstAddress() const {
		return _dstAddress;
	}

	string getDstIP() const {
		return _dstIP;
	}
	
	string getDstPort() const {
		return _dstPort;
	}
	
	/**
   * Set/Get the local IP address
   */
	@property void localIp(string ip) {
		localIP_ = _ip;
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
		auro tv = Tuple!(ubyte, "maj", ubyte, "min");
		tv.maj = _version[0];
		tv.min = _version[1];
		return tv;
	}

	@property void url(string url){ 
		auto idx = url.indexOf('?');
		if (idx != -1){
			request()._path = url[0..idx];
			request()._query = url[idx+1..$];
		}
		request()._url = url;
	}

	@property string url(){return request()._url;}

	/**
   * Access the path component (fpreq)
   */
	string getPath() const {
		return request()._path;
	}
	
	/**
   * Access the query component (fpreq)
   */
	string getQueryString() const {
		return request()._query;
	}

	@property void statusMessage(string msg) {
		response()._statusMsg = msg;
	}
	@property string statusMessage() const {
		return response()._statusMsg;
	}

	/**
   * Access the status code (fpres)
   */
	@property void setStatusCode(ushort status)
	{
		response()._status = status;
	}
	@property ushort statusCode() const
	{
		return response()._status;
	}

	/**
   * Access the headers (fpreq, fpres)
   */
	inout(HTTPHeaders) getHeaders() inout { return _headers; }

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
					_headers.set(HTTP_HEADER_MAX_FORWARDS,to!string(max_forwards - 1));
				}
			}
		}
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
	bool is1xxResponse() const { return (statusCode() / 100) == 1; }

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
	void constructDirectResponse(ubyte maj,ubyte min,const int statuscode,string statusMsg,int contentLength = 0)
	{
		statusCode(statuscode);
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
	bool hasQueryParam(string name) const
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
	voif setQueryString(string query)
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
		return fields_.peek!Request() ! is null;
	}
	
	/**
   * @returns true if this HTTPMessage represents an HTTP response
   */
	bool isResponse() const {
		return fields_.peek!Response() ! is null;
	}

protected:
	/** The 12 standard fields for HTTP messages. Use accessors.
   * An HTTPMessage is either a Request or Response.
   * Once an accessor for either is used, that fixes the type of HTTPMessage.
   * If an access is then used for the other type, a DCHECK will fail.
   */
	struct Request {
	Address _clientAddress;
	string _clientIP;
	string _clientPort;
		HTTPMethod _method = HTTPMethod.HTTP_INVAILD;
	string _path;
	string _query;
	string _url;
		
	ushort _pushStatus;
	string _pushStatusStr;
	};
	
	struct Response {
		ushort _status;
		string _statusStr;
		string _statusMsg;
	};

	inout(Request) request() inout
	{
		if(_fields.type == typeid(null))
			_fields = Request();
		return _fields.get!Request();
	}

	inout(Response) response() inout
	{
		if(_fields.type == typeid(null))
			_fields = Response();
		return _fields.get!Response();
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

			});
	}
	void unparseQueryParams(){
		queryParams_.clear();
		parsedQueryParams_ = false;
	}

private:
	Address _dstAddress;
	string _dstIP;
	string _dstPort;
		
	string _localIP;
	string _versionStr;
	Variant _fields;
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
	bool _wantsKeepalive = false;
}

