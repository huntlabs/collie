/*
 * Collie - An asynchronous event-driven network framework using Dlang development
 *
 * Copyright (C) 2015-2016  Shanghai Putao Technology Co., Ltd 
 *
 * Developer: putao's Dlang team
 *
 * Licensed under the Apache-2.0 License.
 *
 */
module collie.codec.http.request;

import std.experimental.logger;
import std.socket;
import std.experimental.allocator.gc_allocator;

import collie.codec.http.header;
import collie.codec.http.parser;
import collie.buffer.sectionbuffer;
import collie.codec.http.config;
import collie.utils.vector;

alias CallBackHeader = void delegate(HTTPHeader header);
alias CallBackRequest = void delegate(HTTPRequest header);

class HTTPRequest
{
    this(HTTPConfig config = httpConfig)
    {
        _config = config;
        _header = new HTTPHeader(HTTPHeaderType.HTTP_REQUEST);
        _parser = new HTTPParser(HTTPParserType.HTTP_REQUEST, _config.maxHeaderSize);
        _parser.onMessageBegin = &onMessageBegin;
        _parser.onMessageComplete = &onMssageComplete;
        _parser.onUrl = &onURI;
        _parser.onHeaderField = &onHeaderKey;
        _parser.onHeaderValue = &onHeaderValue;
        _parser.onHeaderComplete = &onHeadersComplete;
        _parser.onChunkHeader = &onChunkHeader;
        _parser.onBody = &onBody;
        _parser.onChunkComplete = &onChunkComplete;
        _body = new SectionBuffer(_config.requestBodyStectionSize, httpAllocator);
        _addr = null;
    }

    ~this()
    {
        _body.destroy;
        _body = null;
        _header.destroy;
        _header = null;
        _parser.destroy;
        _parser = null;
    }

    pragma(inline,true)
    final @property const(HTTPHeader) Header() const
    {
        return _header;
    }

    pragma(inline,true)
    final @property SectionBuffer Body()
    {
        return _body;
    }

    pragma(inline,true)
    final @property Address clientAddress()
    {
        return _addr;
    }

    pragma(inline)
    final bool parserData(ubyte[] data)
    {
        _dorun = true;
        ulong len = _parser.httpParserExecute(data);
        if ((len == data.length || Header.upgrade()) && _dorun)
        {
            if (_headerCompleted && _headerComplete)
                _headerComplete(_header);
            if (_meassComplete && _RequestComplete)
                _RequestComplete(this);
            return true;
        }
        return false;
    }

    pragma(inline)
    final @property headerComplete(CallBackHeader cback)
    {
        _headerComplete = cback;
    }

    pragma(inline)
    final @property requestComplete(CallBackRequest cback)
    {
        _RequestComplete = cback;
    }

package:
    pragma(inline,true)
    final void clear()
    {
        _dorun = false;
        _header.clear();
        _body.clear();
        _headerCompleted = false;
        _meassComplete = false;
        _parser.rest(HTTPParserType.HTTP_REQUEST);
        _addr = null;

    }

    pragma(inline)
    final @property clientAddress(Address addr)
    {
        _addr = addr;
    }

    pragma(inline,true)
    @property HTTPParser parser()
    {
        return _parser;
    }

    pragma(inline,true)
    @property isRuning()
    {
        return _parser.handleIng;
    }

protected:
    final void onMessageBegin(HTTPParser)
    {
        trace("HTTPRequest.onMessageBegin");
        if (!_dorun)
        {
            _parser.handleIng = false;
            return;
        }
        _header.clear();
        _hkey.clear();
        _hvalue.clear();
        _body.clear();
    }

    final void onURI(HTTPParser, ubyte[] data, bool adv)
    {
        trace("HTTPRequest.onURI adv = ", adv, " ,url = ", cast(string) data);
        if (!_dorun)
        {
            _parser.handleIng = false;
            return;
        }
        if (_hkey.empty)
        {
            if (adv)
            {
                _header.requestString = cast(string) data.dup;
                _header.method = _parser.methodCode;
            }
            else
            {
                _hkey.insertBack(data);
            }
        }
        else
        {
            _hkey.insertBack(data);
            if (adv)
            {
                _header.requestString = cast(string) _hkey.dup;
                _hkey.clear();
                _header.method = _parser.methodCode;
            }
        }

    }

    final void onHeaderKey(HTTPParser, ubyte[] data, bool adv)
    {
        trace("HTTPRequest.onHeaderKey adv = ", adv, " ,data  = ", cast(string) data);
        if (!_dorun)
        {
            _parser.handleIng = false;
            return;
        }
        _hkey.insertBack(data);
    }

    final void onHeaderValue(HTTPParser, ubyte[] data, bool adv)
    {
        trace("HTTPRequest.onHeaderValue adv = ", adv, " ,data = ", cast(string) data);
        if (!_dorun)
        {
            _parser.handleIng = false;
            return;
        }
        if (_hvalue.empty)
        {
            if (adv)
            {
                _header.setHeaderValue(cast(string) _hkey.dup, cast(string) data.dup);
                _hkey.clear();
            }
            else
            {
                _hvalue.insertBack(data);
            }
        }
        else
        {
            _hvalue.insertBack(data);
            if (adv)
            {
                _header.setHeaderValue(cast(string) _hkey.dup, cast(string) _hvalue.dup);
                _hkey.clear();
                _hvalue.clear();
            }
        }
    }

    final void onHeadersComplete(HTTPParser)
    {
        trace("HTTPRequest.onHeadersComplete");
        if (!_dorun)
        {
            _parser.handleIng = false;
            return;
        }
        _headerCompleted = true;
        _header.upgrade = _parser.isUpgrade;
        if (_parser.major == 1)
        {
            if (_parser.minor > 0)
            {
                _header.httpVersion = HTTPVersion.HTTP1_1;
            }
            else
            {
                _header.httpVersion = HTTPVersion.HTTP1_0;
            }
        }
        else if (_parser.major == 2)
        {
            _header.httpVersion = HTTPVersion.HTTP2;
        }
        if (_header.upgrade)
        {
            _parser.handleIng = false;
            return;
        }
        trace("HTTPRequest.onHeadersComplete", _parser.contentLength);
    }

    final void onBody(HTTPParser, ubyte[] data, bool adv)
    {
        trace("HTTPRequest.onBody adv = ", adv, " ,data = ", cast(string) data);
        if (!_dorun)
        {
            _parser.handleIng = false;
            return;
        }
        _body.write(data);
        if (_body.length > _config.maxBodySize)
        {
            _parser.handleIng = false;
        }
    }

    final void onMssageComplete(HTTPParser)
    {
        trace("HTTPRequest.onMssageComplete");
        if (!_dorun)
        {
            _parser.handleIng = false;
            return;
        }
        _meassComplete = true;
    }

    final void onChunkHeader(HTTPParser)
    {
        trace("HTTPRequest.onChunkHeader");
        if (!_dorun)
        {
            _parser.handleIng = false;
            return;
        }
    }

    final void onChunkComplete(HTTPParser)
    {
        trace("HTTPRequest.onChunkComplete");
        if (!_dorun)
        {
            _parser.handleIng = false;
            return;
        }
    }

private:
    HTTPHeader _header;
    HTTPParser _parser;
    bool _headerCompleted = false;
    bool _meassComplete = false;

    Address _addr;

    CallBackHeader _headerComplete;
    CallBackRequest _RequestComplete;
    bool _dorun;
private:
    Vector!(ubyte, false, GCAllocator) _hkey;
    Vector!(ubyte, false, GCAllocator) _hvalue;
    SectionBuffer _body;
    HTTPConfig _config;
}
