module collie.codec.http.server.responsebuilder;

import collie.codec.http.server.responsehandler;
import collie.codec.http.httpmessage;
import collie.codec.http.codec.httpcodec;
import collie.codec.http.headers;

import std.conv;


class ResponseBuilder
{
	alias HVector = HTTPCodec.HVector;

	this(ResponseHandler txn)
	{
		setResponseHandler(txn);
	}

	final ResponseBuilder promise(string url, string host)
	{
		if(_txn){
			if(_headers is null)
				_headers = new HTTPMessage();
			_headers.url(url);
			_headers.getHeaders.add(HTTPHeaderCode.HOST,host);
		}
		return this;
	}

	final ResponseBuilder status(ushort code, string message)
	{
		if(_txn){
			if(_headers is null)
				_headers = new HTTPMessage();
			_headers.statusCode(code);
			_headers.statusMessage(message);
		}
		return this;
	}

	final ResponseBuilder header(T = string)(string name,T value)
	{
		if(_txn && _headers)
			_headers.getHeaders.add(name,to!string(value));
		return this;
	}

	final ResponseBuilder header(T = string)(HTTPHeaderCode code,T value)
	{
		if(_txn && _headers)
			_headers.getHeaders.add(code,to!string(value));
		return this;
	}

	final ResponseBuilder setBody(ubyte[] data)
	{
		if(_txn)
			_body.insertBack(data);
		return this;
	}

	final ResponseBuilder connectionClose(){
		return header(HTTPHeaderCode.CONNECTION,"close");
	}

	final void sendWithEOM(){
		_sendEOM = true;
		send();
	}

	final void send()
	{
		trace("_txn is ", cast(void *)_txn);
		if(_txn is null) return;
		scope(exit){
			if(_headers) {
				import collie.utils.memory;
				gcFree(_headers);
			}
			_headers = null;
		}
		bool chunked = true;
		if(_headers && _sendEOM) chunked = false;

		if(_headers){
			trace("is isResponse : ",_headers.isResponse());
			trace("_headers.statusCode : ", _headers.statusCode);
			if(_headers.isResponse() && (_headers.statusCode >= 200)) {
				trace("is chanlk , ", chunked);
				if(chunked) {
					_headers.chunked(true);
				} else {
					_headers.getHeaders.add(HTTPHeaderCode.CONTENT_LENGTH, to!string(_body.length));
				}
			}
			if(_body.empty && _sendEOM && _txn)
				_txn.sendHeadersWithEOM(_headers);
			else if(_txn)_txn.sendHeaders(_headers);
		}
		if(!_body.empty) {
			if(chunked) {
				if(_txn)_txn.sendChunkHeader(_body.length);
				if(_txn)_txn.sendBody(_body.data(true));
				if(_txn)_txn.sendChunkTerminator();
				if(_sendEOM && _txn) 
					_txn.sendEOM();
			} else {
				if(_txn)_txn.sendBody(_body,_sendEOM);
			}
		} else if(_sendEOM && _txn) {
			_txn.sendEOM();
		}
	}

	final @property headers(){return _headers;}
	final @property bodys(){return &_body;}
	final @property responseHandler(){return _txn;};
protected:
	pragma(inline,true) void setResponseHandler(ResponseHandler txn){_txn = txn;}
private:
	ResponseHandler _txn;
	HTTPMessage _headers;
	HVector _body;

	bool _sendEOM = false;
}

