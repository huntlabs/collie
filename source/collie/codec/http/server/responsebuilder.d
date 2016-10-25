module collie.codec.http.server.responsebuilder;

import collie.codec.http.server.responsehandler;
import collie.codec.http.httpmessage;
import collie.codec.http.codec.httpcodec;
import collie.codec.http.headers;

import std.conv;


final class ResponseBuilder
{
	alias HVector = HTTPCodec.HVector;

	this(ResponseHandler txn)
	{
		_txn = txn;
	}

	ResponseBuilder promise(string url, string host)
	{
		_headers = new HTTPMessage();
		_headers.url(url);
		_headers.getHeaders.add(HTTPHeaderCode.HOST,host);
		return this;
	}

	ResponseBuilder status(ushort code, string message)
	{
		_headers = new HTTPMessage();
		_headers.statusCode(code);
		_headers.statusMessage(message);
		return this;
	}

	//@property headers(){return _headers;}

	ResponseBuilder header(T = string)(string name,T value)
	{
		_headers.getHeaders.add(name,to!string(value));
		return this;
	}

	ResponseBuilder header(T = string)(HTTPHeaderCode code,T value)
	{
		_headers.getHeaders.add(code,to!string(value));
		return this;
	}

	ResponseBuilder setBody(ubyte[] data)
	{
		_body.insertBack(data);
		return this;
	}

	void sendWithEOM(){
		_sendEOM = true;
		send();
	}

	void send()
	{
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
			_txn.sendHeaders(_headers);
		}
		if(!_body.empty) {
			if(chunked) {
				_txn.sendChunkHeader(_body.length);
				_txn.sendBody(_body.data(true));
				_txn.sendChunkTerminator();
				if(_sendEOM) 
					_txn.sendEOM();
			} else {
				_txn.sendBody(_body.data(true),_sendEOM);
			}
		} else if(_sendEOM) {
			_txn.sendEOM();
		}
	}

	void acceptUpgradeRequest(bool connect_req,string upgradeProtocol = "") 
	{
		scope(exit){
			if(_headers) {
				import collie.utils.memory;
				gcFree(_headers);
			}
			_headers = null;
		}
		_headers = new HTTPMessage();
		if (connect_req) {
			_headers.setHTTPVersion(1,1);
			_headers.statusCode = 200;
			_headers.statusMessage("OK");
		} else {
			_headers.setHTTPVersion(1,1);
			_headers.statusCode = 101;
			_headers.statusMessage("Switching Protocols");
			_headers.getHeaders().add(HTTPHeaderCode.UPGRADE, upgradeProtocol);
			_headers.getHeaders().add(HTTPHeaderCode.CONNECTION, "Upgrade");
		}
		_txn.sendHeaders(_headers);
	}



private:
	ResponseHandler _txn;
	HTTPMessage _headers;
	HVector _body;

	bool _sendEOM = false;
}

