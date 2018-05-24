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

/**
*/
class ResponseBuilder
{
	this()
	{
		_body = new ByteBuffer!Mallocator();
		_httpMessage = new HttpMessage(HttpMessageType.response);
	}

	this(ResponseHandler txn)
	{
		_txn = txn;
		this();
	}

	final ResponseBuilder promise(string url, string host)
	{
		_httpMessage.url(url);
		_httpMessage.addHeader(HTTPHeaderCode.HOST, host);
		return this;
	}

	final ResponseBuilder status(ushort code, string message)
	{
		debug logDebug("status: ", code, "  message: ", message);

		_httpMessage.statusCode(code);
		_httpMessage.statusMessage(message);

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
	final ResponseBuilder header(T = string)(string name, T value)
	{
		_httpMessage.setHeader(name, to!string(value));
		return this;
	}

	final ResponseBuilder header(T = string)(HttpHeaderCode code, T value)
	{
		_httpMessage.setHeader(code, to!string(value));
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
		validate();
		foreach (string key, string value; headers)
			_httpMessage.addHeader(key, value);
		return this;
	}

	final ResponseBuilder setBody(in ubyte[] data)
	{
		_body.write(data);
		return this;
	}

	final ResponseBuilder connectionClose()
	{
		return header(HTTPHeaderCode.CONNECTION, "close");
	}

	final void sendWithEOM()
	{
		_sendEOM = true;
		send();
	}

	final void send()
	{
		validate();
		// version(CollieDebugMode) 
		// logDebug("_txn is ", cast(void *)_txn);
		bool chunked = true;
		if (_sendEOM)
			chunked = false;
	
		version(CollieDebugMode) 
		logDebug("is isResponse : ",_httpMessage.isResponse());
		version (CollieDebugMode)
		logDebug("resonse status code: ", _httpMessage.statusCode);

		if (_httpMessage.statusCode >= 200 && _httpMessage.isResponse())
		{
			version (CollieDebugMode)
				logDebug("Chunked: ", chunked);
			if (chunked)
			{
				_httpMessage.chunked(true);
			}
			else
			{
				_httpMessage.chunked(false);
				_httpMessage.setHeader(HTTPHeaderCode.CONTENT_LENGTH, to!string(_body.length));
			}
		}
		if (_txn)
		{
			if ((_body.length == 0) && _sendEOM)
			{
				_txn.sendHeadersWithEOM(_httpMessage);
				return;
			}
			else
			{
				_txn.sendHeaders(_httpMessage);
			}
		}
		
		if ((_body.length > 0) && _txn)
		{
			version (CollieDebugMode)
				logDebug("body len = ", _body.length);
			if (chunked)
			{
				_txn.sendChunkHeader(_body.length);
				_txn.sendBody(_body.allData.data());
			}
			else
			{
				_txn.sendBody(_body.allData.data(), _sendEOM);
				return;
			}
			_body.clear();
		}
		if (_sendEOM && _txn)
		{
			_txn.sendEOM();
		}
	}

	void clear()
	{
		_isDisposed = true;
		_txn = null;
	}

	private void validate()
	{
		assert(!_isDisposed, "The resources have been released!");
	}

	@property HttpMessage httpMessage()
	{
		return _httpMessage;
	}

	final @property HttpMessage headers()
	{
		return _httpMessage;
	}

	final @property ByteBuffer!Mallocator* bodys()
	{
		return &_body;
	}

	@property ResponseHandler dataHandler()
	{
		return _txn;
	}

	@property void dataHandler(ResponseHandler txn)
	{
		_txn = txn;
	}

protected:
	HttpMessage _httpMessage;
	ByteBuffer!Mallocator _body;
	ResponseHandler _txn;

private:
	bool _sendEOM = false;
	bool _isDisposed = false;
}
