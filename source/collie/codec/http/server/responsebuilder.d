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
module collie.codec.http.server.responsebuilder;
import kiss.logger;
import collie.codec.http.server.responsehandler;
import collie.codec.http.httpmessage;
import collie.codec.http.codec.httpcodec;
import collie.codec.http.headers;
import kiss.container.ByteBuffer;
import std.experimental.allocator.mallocator;

import std.conv;


class ResponseBuilder
{
	this(ResponseHandler txn)
	{
		setResponseHandler(txn);
		_body = new ByteBuffer!Mallocator();
		_httpMessage = new HTTPMessage();
		_headers = _httpMessage.getHeaders();
	}

	final ResponseBuilder promise(string url, string host)
	{
		if(_txn){
			if(_httpMessage is null)
			{
				_httpMessage = new HTTPMessage();
				_headers = _httpMessage.getHeaders();
			}
			_httpMessage.url(url);
			_httpMessage.getHeaders.add(HTTPHeaderCode.HOST,host);
		}
		return this;
	}

	final ResponseBuilder status(ushort code, string message)
	{
		if(_txn){
			debug logDebug("status: ", code, "  message: ", message);
			if(_httpMessage is null)
			{
				_httpMessage = new HTTPMessage();
				_headers = _httpMessage.getHeaders();
			}
			_httpMessage.statusCode(code);
			_httpMessage.statusMessage(message);
		}
		return this;
	}
	
	/**
     * Get the status code for the response.
     *
     * @return int
     */
    int status()
    {
        return _httpMessage.statusCode();
    }

    /**
     * Set a header on the Response.
     *
     * @param  string  $key
     * @param  array|string  $values
     * @return $this
     */
	final ResponseBuilder header(T = string)(string name,T value)
	{
		if(_txn && _httpMessage)
			_httpMessage.getHeaders.add(name,to!string(value));
		return this;
	}

	final ResponseBuilder header(T = string)(HTTPHeaderCode code,T value)
	{
		if(_txn && _httpMessage)
			_httpMessage.getHeaders.add(code,to!string(value));
		return this;
	}

	/**
     * Add an array of headers to the response.
     *
     * @param  array  $headers
     * @return $this
     */
    ResponseBuilder withHeaders(string[string] headers)
    {
        foreach (string key, string value; headers) {
           _headers.add(key, value);
        }
        return this;
    }


	final ResponseBuilder setBody(ubyte[] data)
	{
		if(_txn)
			_body.write(data);
		originalContent = data;
		return this;
	}
	protected const(ubyte)[] originalContent;

	final ResponseBuilder connectionClose(){
		return header(HTTPHeaderCode.CONNECTION,"close");
	}

	final void sendWithEOM(){
		_sendEOM = true;
		send();
	}

	final void send()
	{
		// version(CollieDebugMode) logDebug("_txn is ", cast(void *)_txn);
		scope(exit){
			_headers = null;
			_httpMessage = null;
		}
		bool chunked = true;
		if(_httpMessage && _sendEOM) chunked = false;

		if(_httpMessage){
			// version(CollieDebugMode) logDebug("is isResponse : ",_httpMessage.isResponse());
			version(CollieDebugMode) logDebug("resonse status code: ", _httpMessage.statusCode);
			if(_httpMessage.isResponse() && (_httpMessage.statusCode >= 200)) {
				version(CollieDebugMode) logDebug("Chunked: ", chunked);
				if(chunked) {
					_httpMessage.chunked(true);
				} else {
					_httpMessage.chunked(false);
					_httpMessage.getHeaders.add(HTTPHeaderCode.CONTENT_LENGTH, to!string(_body.length));
				}
			}
			if(_txn) {
				if((_body.length == 0) && _sendEOM) {
					_txn.sendHeadersWithEOM(_httpMessage);
					return;
				}else {
					_txn.sendHeaders(_httpMessage);
				}
			}
		}
		if((_body.length > 0) && _txn) {
			version(CollieDebugMode) logDebug("body len = ", _body.length);
			if(chunked) {
				_txn.sendChunkHeader(_body.length);
				_txn.sendBody(_body.allData.data());
			} else {
				_txn.sendBody(_body.allData.data(),_sendEOM);
				return;
			}
			_body.clear();
		}
		if(_sendEOM && _txn) {
			_txn.sendEOM();
		}
	}

	@property HttpMessage httpMessage(){return _httpMessage;}
	final @property HTTPMessage headers(){return _httpMessage;}
	final @property ByteBuffer!Mallocator* bodys(){return &_body;}
	final @property ResponseHandler responseHandler(){return _txn;};
protected:
	pragma(inline) final void setResponseHandler(ResponseHandler txn){_txn = txn;}
	HTTPMessage _httpMessage;
	HttpHeaders _headers;
	ByteBuffer!Mallocator _body;

private:
	ResponseHandler _txn;
	bool _sendEOM = false;
}

