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
module collie.codec.http.parser;

import std.experimental.logger;
import collie.codec.http.headers.httpmethod;
public import collie.codec.http.parser.parsertype;

/** ubyte[] 为传过去字段里的位置引用，没有数据拷贝，自己使用的时候注意拷贝数据， 
 bool 此段数据是否完结，可能只是数据的一部分。
 */
alias CallBackData = void delegate(ref HTTPParser, ubyte[], bool);
alias CallBackNotify = void delegate(ref HTTPParser);

struct HTTPParser
{
    this(HTTPParserType ty, uint maxHeaderSize = 4096)
    {
		rest(ty, maxHeaderSize);
    }

    pragma(inline,true)
    @property type()
    {
        return _type;
    }

    pragma(inline,true)
    @property isUpgrade()
    {
        return _upgrade;
    }

    pragma(inline,true)
    @property contentLength()
    {
        return _contentLength;
    }

    pragma(inline,true)
    @property isChunked()
    {
        return (_flags & HTTPParserFlags.F_CHUNKED) == 0 ? false : true;
    }
    //@property status() {return _statusCode;}
    pragma(inline,true)
    @property error()
    {
        return _httpErrno;
    }

    pragma(inline,true)
    @property errorString()
    {
        return error_string[_httpErrno];
    }

    pragma(inline,true)
    @property methodCode()
    {
        return _method;
    }

    pragma(inline,true)
    @property methodString()
    {
        return method_strings[_method];
    }

	pragma(inline,true)
	@property statusCode()
	{
		return _statusCode;
	}
    pragma(inline,true)
    @property major()
    {
        return _httpMajor;
    }

    //版本号首位
    pragma(inline,true)
    @property minor()
    {
        return _httpMinor;
    }

    //版本号末尾
    pragma(inline,true)
    @property handleIng()
    {
        return _isHandle;
    }

    pragma(inline)
    @property handleIng(bool handle)
    {
        _isHandle = handle;
    }

    pragma(inline,true)
    @property skipBody()
    {
        return _skipBody;
    }

    pragma(inline)
    @property skipBody(bool skip)
    {
        return _skipBody = skip;
    }
    
    pragma(inline,true)
    @property keepalive()
    {
		return _keepAlive;
    }

    /** 回调函数指定 */
    pragma(inline)
    @property onMessageBegin(CallBackNotify cback)
    {
        _onMessageBegin = cback;
    }

    pragma(inline)
    @property onMessageComplete(CallBackNotify cback)
    {
        _onMessageComplete = cback;
    }

    pragma(inline)
    @property onHeaderComplete(CallBackNotify cback)
    {
        _onHeadersComplete = cback;
    }

    pragma(inline)
    @property onChunkHeader(CallBackNotify cback)
    {
        _onChunkHeader = cback;
    }

    pragma(inline)
    @property onChunkComplete(CallBackNotify cback)
    {
        _onChunkComplete = cback;
    }

    pragma(inline)
    @property onUrl(CallBackData cback)
    {
        _onUrl = cback;
    }

    pragma(inline)
    @property onStatus(CallBackData cback)
    {
        _onStatus = cback;
    }

    pragma(inline)
    @property onHeaderField(CallBackData cback)
    {
        _onHeaderField = cback;
    }

    pragma(inline)
    @property onHeaderValue(CallBackData cback)
    {
        _onHeaderValue = cback;
    }

    pragma(inline)
    @property onBody(CallBackData cback)
    {
        _onBody = cback;
    }

    pragma(inline)
		void rest(HTTPParserType ty, uint maxHeaderSize = 4096)
    {
        type = ty;
		_maxHeaderSize = maxHeaderSize;
        _state = (
            type == HTTPParserType.HTTP_REQUEST ? HTTPParserState.s_start_req : (
            type == HTTPParserType.HTTP_RESPONSE ? HTTPParserState.s_start_res
            : HTTPParserState.s_start_req_or_res));
        _httpErrno = HTTPParserErrno.HPE_OK;
        _flags = HTTPParserFlags.F_ZERO;
		_isHandle = false;
		_skipBody = false;
		_keepAlive = 0x00;
    }

protected:
    CallBackNotify _onMessageBegin;

    CallBackNotify _onHeadersComplete;

    CallBackNotify _onMessageComplete;

    CallBackNotify _onChunkHeader;

    CallBackNotify _onChunkComplete;

    CallBackData _onUrl;

    CallBackData _onStatus;

    CallBackData _onHeaderField;

    CallBackData _onHeaderValue;

    CallBackData _onBody;

public:

    pragma(inline)
    bool bodyIsFinal()
    {
        return _state == HTTPParserState.s_message_done;
    }

    ulong httpParserExecute(ubyte[] data)
    {
        handleIng = true;
        scope (exit)
            handleIng = false;
        ubyte c, ch;
        byte unhexVal;
        size_t mHeaderFieldMark = size_t.max;
        size_t mHeaderValueMark = size_t.max;
        size_t mUrlMark = size_t.max;
        size_t mBodyMark = size_t.max;
        size_t mStatusMark = size_t.max;
        size_t maxP = cast(long) data.length;
        size_t p = 0;
        if (_httpErrno != HTTPParserErrno.HPE_OK)
        {
			trace("_httpErrno eror : ", _httpErrno);
            return 0;
        }
		trace("data.lengt : ",data.length, "   _state = ", _state);
        if (data.length == 0)
        {
            switch (_state)
            {
            case HTTPParserState.s_body_identity_eof:
                /* Use of CALLBACK_NOTIFY() here would erroneously return 1 byte read if
					 * we got paused.
					 */
                mixin(
                    CALLBACK_NOTIFY_NOADVANCE("MessageComplete"));
                return 0;

            case HTTPParserState.s_dead:
            case HTTPParserState.s_start_req_or_res:
            case HTTPParserState.s_start_res:
            case HTTPParserState.s_start_req:
                return 0;

            default:
                //_httpErrno = HTTPParserErrno.HPE_INVALID_EOF_STATE);
                _httpErrno = HTTPParserErrno.HPE_INVALID_EOF_STATE;
                return 1;
            }
        }

        if (_state == HTTPParserState.s_header_field)
            mHeaderFieldMark = 0;
        if (_state == HTTPParserState.s_header_value)
            mHeaderValueMark = 0;
        switch (_state)
        {
        case HTTPParserState.s_req_path:
        case HTTPParserState.s_req_schema:
        case HTTPParserState.s_req_schema_slash:
        case HTTPParserState.s_req_schema_slash_slash:
        case HTTPParserState.s_req_server_start:
        case HTTPParserState.s_req_server:
        case HTTPParserState.s_req_server_with_at:
        case HTTPParserState.s_req_query_string_start:
        case HTTPParserState.s_req_query_string:
        case HTTPParserState.s_req_fragment_start:
        case HTTPParserState.s_req_fragment:
            mUrlMark = 0;
            break;
        case HTTPParserState.s_res_status:
            mStatusMark = 0;
            break;
        default:
            break;
        }
        for (; p < maxP; ++p)
        {
            ch = data[p];
            if (_state <= HTTPParserState.s_headers_done)
            {
                _nread += 1;
                if (_nread > _maxHeaderSize)
                {
                    _httpErrno = HTTPParserErrno.HPE_HEADER_OVERFLOW;
                    goto error;
                }
            }

        reexecute:
            switch (_state)
            {
            case HTTPParserState.s_dead:
                /* this _state is used after a 'Connection: close' message
					 * the parser will error out if it reads another message
					 */
                if (ch == CR || ch == LF)
                    break;

                _httpErrno = HTTPParserErrno.HPE_CLOSED_CONNECTION;
                goto error;
            case HTTPParserState.s_start_req_or_res:
                {
                    if (ch == CR || ch == LF)
                        break;
                    _flags = HTTPParserFlags.F_ZERO;
                    _contentLength = ulong.max;

                    if (ch == 'H')
                    {
                        _state = HTTPParserState.s_res_or_resp_H;

                        mixin(CALLBACK_NOTIFY("MessageBegin")); // 开始处理

                    }
                    else
                    {
                        type = HTTPParserType.HTTP_REQUEST;
                        _state = HTTPParserState.s_start_req;
                        goto reexecute;
                    }

                    break;
                }
            case HTTPParserState.s_res_or_resp_H:
                if (ch == 'T')
                {
                    type = HTTPParserType.HTTP_RESPONSE;
                    _state = HTTPParserState.s_res_HT;
                }
                else
                {
                    if (ch != 'E')
                    {
                        _httpErrno = HTTPParserErrno.HPE_INVALID_CONSTANT;
                        goto error;
                    }

                    type = HTTPParserType.HTTP_REQUEST;
                    _method = HTTPMethod.HTTP_HEAD;
                    _index = 2;
                    _state = HTTPParserState.s_req_method;
                }
                break;

            case HTTPParserState.s_start_res:
                {
                    _flags = HTTPParserFlags.F_ZERO;
                    _contentLength = ulong.max;

                    switch (ch)
                    {
                    case 'H':
                        _state = HTTPParserState.s_res_H;
                        break;

                    case CR:
                    case LF:
                        break;

                    default:
                        _httpErrno = HTTPParserErrno.HPE_INVALID_CONSTANT;
                        goto error;
                    }
                    mixin(CALLBACK_NOTIFY("MessageBegin"));
                    break;
                }
            case HTTPParserState.s_res_H:
                mixin(STRICT_CHECK("ch != 'T'"));
                _state = HTTPParserState.s_res_HT;
                break;

            case HTTPParserState.s_res_HT:
                //STRICT_CHECK(ch != 'T');
                mixin(STRICT_CHECK("ch != 'T'"));
                _state = HTTPParserState.s_res_HTT;
                break;

            case HTTPParserState.s_res_HTT:
                //STRICT_CHECK(ch != 'P');
                mixin(STRICT_CHECK("ch != 'P'"));
                _state = HTTPParserState.s_res_HTTP;
                break;

            case HTTPParserState.s_res_HTTP:
                //STRICT_CHECK(ch != '/');
                mixin(STRICT_CHECK("ch != '/'"));
                _state = HTTPParserState.s_res_first_http_major;
                break;

            case HTTPParserState.s_res_first_http_major:
                if (ch < '0' || ch > '9')
                {
                    _httpErrno = HTTPParserErrno.HPE_INVALID_VERSION;
                    goto error;
                }

                _httpMajor = cast(ushort)(ch - '0');
                _state = HTTPParserState.s_res_http_major;
                break;

                /* major HTTP version or dot */
            case HTTPParserState.s_res_http_major:
                {
                    if (ch == '.')
                    {
                        _state = HTTPParserState.s_res_first_http_minor;
                        break;
                    }

                    if (!mixin(IS_NUM("ch")))
                    {
                        _httpErrno = HTTPParserErrno.HPE_INVALID_VERSION;
                        goto error;
                    }

                    _httpMajor *= 10;
                    _httpMajor += ch - '0';

                    if (_httpMajor > 999)
                    {
                        _httpErrno = HTTPParserErrno.HPE_INVALID_VERSION;
                        goto error;
                    }

                    break;
                }

                /* first digit of minor HTTP version */
            case HTTPParserState.s_res_first_http_minor:
                if (!mixin(IS_NUM("ch")))
                {
                    _httpErrno = HTTPParserErrno.HPE_INVALID_VERSION;
                    goto error;
                }

                _httpMinor = cast(ushort)(ch - '0');
                _state = HTTPParserState.s_res_http_minor;
                break;

                /* minor HTTP version or end of request line */
            case HTTPParserState.s_res_http_minor:
                {
                    if (ch == ' ')
                    {
                        _state = HTTPParserState.s_res_first_status_code;
                        break;
                    }

                    if (!mixin(IS_NUM("ch")))
                    {
                        _httpErrno = HTTPParserErrno.HPE_INVALID_VERSION;
                        goto error;
                    }

                    _httpMinor *= 10;
                    _httpMinor += ch - '0';

                    if (_httpMinor > 999)
                    {
                        _httpErrno = HTTPParserErrno.HPE_INVALID_VERSION;
                        goto error;
                    }

                    break;
                }

            case HTTPParserState.s_res_first_status_code:
                {
                    if (!mixin(IS_NUM("ch")))
                    {
                        if (ch == ' ')
                        {
                            break;
                        }

                        _httpErrno = HTTPParserErrno.HPE_INVALID_STATUS;
                        goto error;
                    }
                    _statusCode = ch - '0';
                    _state = HTTPParserState.s_res_status_code;
                    break;
                }

            case HTTPParserState.s_res_status_code:
                {
                    if (!mixin(IS_NUM("ch")))
                    {
                        switch (ch)
                        {
                        case ' ':
                            _state = HTTPParserState.s_res_status_start;
                            break;
                        case CR:
                            _state = HTTPParserState.s_res_line_almost_done;
                            break;
                        case LF:
                            _state = HTTPParserState.s_header_field_start;
                            break;
                        default:
                            _httpErrno = HTTPParserErrno.HPE_INVALID_STATUS;
                            goto error;
                        }
                        break;
                    }

                    _statusCode *= 10;
                    _statusCode += ch - '0';

                    if (_statusCode > 999)
                    {
                        _httpErrno = HTTPParserErrno.HPE_INVALID_STATUS;
                        goto error;
                    }

                    break;
                }

            case HTTPParserState.s_res_status_start:
                {
                    if (ch == CR)
                    {
                        _state = HTTPParserState.s_res_line_almost_done;
                        break;
                    }

                    if (ch == LF)
                    {
                        _state = HTTPParserState.s_header_field_start;
                        break;
                    }

                    //MARK(status);
                    if (mStatusMark == size_t.max)
                    {
                        mStatusMark = p;
                    }
                    _state = HTTPParserState.s_res_status;
                    _index = 0;
                    break;
                }

            case HTTPParserState.s_res_status:
                if (ch == CR)
                {
                    _state = HTTPParserState.s_res_line_almost_done;
                    mixin(CALLBACK_DATA("Status"));
                    break;
                }

                if (ch == LF)
                {
                    _state = HTTPParserState.s_header_field_start;
                    //statusCall();
                    mixin(CALLBACK_DATA("Status"));
                    break;
                }

                break;

            case HTTPParserState.s_res_line_almost_done:
                mixin(STRICT_CHECK("ch != LF"));
                _state = HTTPParserState.s_header_field_start;
                break;

            case HTTPParserState.s_start_req:
                {
                    if (ch == CR || ch == LF)
                        break;
                    _flags = HTTPParserFlags.F_ZERO;
                    _contentLength = ulong.max;

                    if (!mixin(IS_ALPHA("ch")))
                    {
                        //error("err0");
                        _httpErrno = HTTPParserErrno.HPE_INVALID_METHOD;
                        goto error;
                    }

                    _index = 1;
                    switch (ch)
                    {
                    case 'A':
                        _method = HTTPMethod.HTTP_ACL;
                        break;
                    case 'B':
                        _method = HTTPMethod.HTTP_BIND;
                        break;
                    case 'C':
                        _method = HTTPMethod.HTTP_CONNECT; /* or COPY, CHECKOUT */ break;
                    case 'D':
                        _method = HTTPMethod.HTTP_DELETE;
                        break;
                    case 'G':
                        _method = HTTPMethod.HTTP_GET;
                        break;
                    case 'H':
                        _method = HTTPMethod.HTTP_HEAD;
                        break;
                    case 'L':
                        _method = HTTPMethod.HTTP_LOCK; /* or LINK */ break;
                    case 'M':
                        _method = HTTPMethod.HTTP_MKCOL; /* or MOVE, MKACTIVITY, MERGE, M-SEARCH, MKCALENDAR */ break;
                    case 'N':
                        _method = HTTPMethod.HTTP_NOTIFY;
                        break;
                    case 'O':
                        _method = HTTPMethod.HTTP_OPTIONS;
                        break;
                    case 'P':
                        _method = HTTPMethod.HTTP_POST;
                        /* or PROPFIND|PROPPATCH|PUT|PATCH|PURGE */
                        break;
                    case 'R':
                        _method = HTTPMethod.HTTP_REPORT; /* or REBIND */ break;
                    case 'S':
                        _method = HTTPMethod.HTTP_SUBSCRIBE; /* or SEARCH */ break;
                    case 'T':
                        _method = HTTPMethod.HTTP_TRACE;
                        break;
                    case 'U':
                        _method = HTTPMethod.HTTP_UNLOCK; /* or UNSUBSCRIBE, UNBIND, UNLINK */ break;
                    default:
                        //error("err0");
                        _httpErrno = HTTPParserErrno.HPE_INVALID_METHOD;
                        goto error;
                    }
                    _state = HTTPParserState.s_req_method;

                    mixin(CALLBACK_NOTIFY("MessageBegin"));
                    break;
                }

            case HTTPParserState.s_req_method:
                {
                    if (ch == '\0')
                    {
                        //error("err0");
                        _httpErrno = HTTPParserErrno.HPE_INVALID_METHOD;
                        goto error;
                    }

                    string matcher = method_strings[_method];
                    if (ch == ' ' && matcher.length == _index)
                    {
                        _state = HTTPParserState.s_req_spaces_before_url;
                    }
                    else if (ch == matcher[_index])
                    {
                        //; /* nada */
                    }
                    else if (_method == HTTPMethod.HTTP_CONNECT)
                    {
                        if (_index == 1 && ch == 'H')
                        {
                            _method = HTTPMethod.HTTP_CHECKOUT;
                        }
                        else if (_index == 2 && ch == 'P')
                        {
                            _method = HTTPMethod.HTTP_COPY;
                        }
                        else
                        {
                            //error("err0");
                            _httpErrno = HTTPParserErrno.HPE_INVALID_METHOD;
                            goto error;
                        }
                    }
                    else if (_method == HTTPMethod.HTTP_MKCOL)
                    {
                        if (_index == 1 && ch == 'O')
                        {
                            _method = HTTPMethod.HTTP_MOVE;
                        }
                        else if (_index == 1 && ch == 'E')
                        {
                            _method = HTTPMethod.HTTP_MERGE;
                        }
                        else if (_index == 1 && ch == '-')
                        {
                            _method = HTTPMethod.HTTP_MSEARCH;
                        }
                        else if (_index == 2 && ch == 'A')
                        {
                            _method = HTTPMethod.HTTP_MKACTIVITY;
                        }
                        else if (_index == 3 && ch == 'A')
                        {
                            _method = HTTPMethod.HTTP_MKCALENDAR;
                        }
                        else
                        {
                            //error("err0");
                            _httpErrno = HTTPParserErrno.HPE_INVALID_METHOD;
                            goto error;
                        }
                    }
                    else if (_method == HTTPMethod.HTTP_SUBSCRIBE)
                    {
                        if (_index == 1 && ch == 'E')
                        {
                            _method = HTTPMethod.HTTP_SEARCH;
                        }
                        else
                        {
                            //error("err0");
                            _httpErrno = HTTPParserErrno.HPE_INVALID_METHOD;
                            goto error;
                        }
                    }
                    else if (_method == HTTPMethod.HTTP_REPORT)
                    {
                        if (_index == 2 && ch == 'B')
                        {
                            //error("err0");
                            _method = HTTPMethod.HTTP_REBIND;
                        }
                        else
                        {
                            _httpErrno = HTTPParserErrno.HPE_INVALID_METHOD;
                            goto error;
                        }
                    }
                    else if (_index == 1)
                    {
                        if (_method == HTTPMethod.HTTP_POST)
                        {

                            if (ch == 'R')
                            {
                                _method = HTTPMethod.HTTP_PROPFIND; /* or HTTP_PROPPATCH */
                            }
                            else if (ch == 'U')
                            {
                                _method = HTTPMethod.HTTP_PUT; /* or HTTP_PURGE */
                            }
                            else if (ch == 'A')
                            {
                                _method = HTTPMethod.HTTP_PATCH;
                            }
                            else
                            {
                                //error("err0");
                                _httpErrno = HTTPParserErrno.HPE_INVALID_METHOD;
                                goto error;
                            }
                        }
                        else if (_method == HTTPMethod.HTTP_LOCK)
                        {
                            if (ch == 'I')
                            {
                                _method = HTTPMethod.HTTP_LINK;
                            }
                            else
                            {
                                //error("err0");
                                _httpErrno = HTTPParserErrno.HPE_INVALID_METHOD;
                                goto error;
                            }
                        }
                    }
                    else if (_index == 2)
                    {
                        if (_method == HTTPMethod.HTTP_PUT)
                        {
                            if (ch == 'R')
                            {
                                _method = HTTPMethod.HTTP_PURGE;
                            }
                            else
                            {
                                //error("err0");
                                _httpErrno = HTTPParserErrno.HPE_INVALID_METHOD;
                                goto error;
                            }
                        }
                        else if (_method == HTTPMethod.HTTP_UNLOCK)
                        {
                            if (ch == 'S')
                            {
                                _method = HTTPMethod.HTTP_UNSUBSCRIBE;
                            }
                            else if (ch == 'B')
                            {
                                _method = HTTPMethod.HTTP_UNBIND;
                            }
                            else
                            {
                                //error("err0");
                                _httpErrno = HTTPParserErrno.HPE_INVALID_METHOD;
                                goto error;
                            }
                        }
                        else
                        {
                            //error("err0");
                            _httpErrno = HTTPParserErrno.HPE_INVALID_METHOD;
                            goto error;
                        }
                    }
                    else if (_index == 4 && _method == HTTPMethod.HTTP_PROPFIND && ch == 'P')
                    {
                        _method = HTTPMethod.HTTP_PROPPATCH;
                    }
                    else if (_index == 3 && _method == HTTPMethod.HTTP_UNLOCK && ch == 'I')
                    {
                        _method = HTTPMethod.HTTP_UNLINK;
                    }
                    else
                    {
                        //error("err0");
                        _httpErrno = HTTPParserErrno.HPE_INVALID_METHOD;
                        goto error;
                    }

                    ++_index;
                    break;
                }

            case HTTPParserState.s_req_spaces_before_url:
                {
                    if (ch == ' ')
                        break;

                    //MARK(url);
                    if (mUrlMark == size_t.max)
                    {
                        mUrlMark = p;
                    }
                    if (_method == HTTPMethod.HTTP_CONNECT)
                    {
                        _state = HTTPParserState.s_req_server_start;
                    }

                    _state = parseURLchar(_state, ch);
                    if (_state == HTTPParserState.s_dead)
                    {
                        _httpErrno = HTTPParserErrno.HPE_INVALID_URL;
                        goto error;
                    }

                    break;
                }

            case HTTPParserState.s_req_schema:
            case HTTPParserState.s_req_schema_slash:
            case HTTPParserState.s_req_schema_slash_slash:
            case HTTPParserState.s_req_server_start:
                {
                    switch (ch)
                    {
                        /* No whitespace allowed here */
                    case ' ':
                    case CR:
                    case LF:
                        _httpErrno = HTTPParserErrno.HPE_INVALID_URL;
                        goto error;
                    default:
                        _state = parseURLchar(_state, ch);
                        if (_state == HTTPParserState.s_dead)
                        {
                            _httpErrno = HTTPParserErrno.HPE_INVALID_URL;
                            goto error;
                        }
                    }

                    break;
                }

            case HTTPParserState.s_req_server:
            case HTTPParserState.s_req_server_with_at:
            case HTTPParserState.s_req_path:
            case HTTPParserState.s_req_query_string_start:
            case HTTPParserState.s_req_query_string:
            case HTTPParserState.s_req_fragment_start:
            case HTTPParserState.s_req_fragment:
                {
                    switch (ch)
                    {
                    case ' ':
                        _state = HTTPParserState.s_req_http_start;
                        mixin(CALLBACK_DATA("Url"));
                        break;
                    case CR:
                    case LF:
                        _httpMajor = 0;
                        _httpMinor = 9;
                        _state = (ch == CR) ? HTTPParserState.s_req_line_almost_done
                            : HTTPParserState.s_header_field_start;
                        mixin(CALLBACK_DATA("Url"));
                        break;
                    default:
                        _state = parseURLchar(_state, ch);
                        if (_state == HTTPParserState.s_dead)
                        {
                            _httpErrno = HTTPParserErrno.HPE_INVALID_URL;
                            goto error;
                        }
                    }
                    break;
                }

            case HTTPParserState.s_req_http_start:
                switch (ch)
                {
                case 'H':
                    _state = HTTPParserState.s_req_http_H;
                    break;
                case ' ':
                    break;
                default:
                    _httpErrno = HTTPParserErrno.HPE_INVALID_CONSTANT;
                    goto error;
                }
                break;

            case HTTPParserState.s_req_http_H:
                mixin(STRICT_CHECK("ch != 'T'"));
                _state = HTTPParserState.s_req_http_HT;
                break;

            case HTTPParserState.s_req_http_HT:
                //STRICT_CHECK(ch != 'T');
                mixin(STRICT_CHECK("ch != 'T'"));
                _state = HTTPParserState.s_req_http_HTT;
                break;

            case HTTPParserState.s_req_http_HTT:
                //STRICT_CHECK(ch != 'P');
                mixin(STRICT_CHECK("ch != 'P'"));
                _state = HTTPParserState.s_req_http_HTTP;
                break;

            case HTTPParserState.s_req_http_HTTP:
                //STRICT_CHECK(ch != '/');
                mixin(STRICT_CHECK("ch != '/'"));
                _state = HTTPParserState.s_req_first_http_major;
                break;

                /* first digit of major HTTP version */
            case HTTPParserState.s_req_first_http_major:
                if (ch < '1' || ch > '9')
                {
                    _httpErrno = HTTPParserErrno.HPE_INVALID_VERSION;
                    goto error;
                }

                _httpMajor = cast(ushort)(ch - '0');
                _state = HTTPParserState.s_req_http_major;
                break;

                /* major HTTP version or dot */
            case HTTPParserState.s_req_http_major:
                {
                    if (ch == '.')
                    {
                        _state = HTTPParserState.s_req_first_http_minor;
                        break;
                    }

                    if (!mixin(IS_NUM("ch")))
                    {
                        _httpErrno = HTTPParserErrno.HPE_INVALID_VERSION;
                        goto error;
                    }

                    _httpMajor *= 10;
                    _httpMajor += ch - '0';

                    if (_httpMajor > 999)
                    {
                        _httpErrno = HTTPParserErrno.HPE_INVALID_VERSION;
                        goto error;
                    }

                    break;
                }

                /* first digit of minor HTTP version */
            case HTTPParserState.s_req_first_http_minor:
                if (!mixin(IS_NUM("ch")))
                {
                    _httpErrno = HTTPParserErrno.HPE_INVALID_VERSION;
                    goto error;
                }

                _httpMinor = cast(ushort)(ch - '0');
                _state = HTTPParserState.s_req_http_minor;
                break;

                /* minor HTTP version or end of request line */
            case HTTPParserState.s_req_http_minor:
                {
                    if (ch == CR)
                    {
                        _state = HTTPParserState.s_req_line_almost_done;
                        break;
                    }

                    if (ch == LF)
                    {
                        _state = HTTPParserState.s_header_field_start;
                        break;
                    }

                    /* XXX allow spaces after digit? */

                    if (!mixin(IS_NUM("ch")))
                    {
                        _httpErrno = HTTPParserErrno.HPE_INVALID_VERSION;
                        goto error;
                    }

                    _httpMinor *= 10;
                    _httpMinor += ch - '0';

                    if (_httpMinor > 999)
                    {
                        _httpErrno = HTTPParserErrno.HPE_INVALID_VERSION;
                        goto error;
                    }

                    break;
                }

                /* end of request line */
            case HTTPParserState.s_req_line_almost_done:
                {
                    if (ch != LF)
                    {
                        _httpErrno = HTTPParserErrno.HPE_LF_EXPECTED;
                        goto error;
                    }

                    _state = HTTPParserState.s_header_field_start;
                    break;
                }

            case HTTPParserState.s_header_field_start:
                {
                    if (ch == CR)
                    {
                        _state = HTTPParserState.s_headers_almost_done;
                        break;
                    }

                    if (ch == LF)
                    {
                        /* they might be just sending \n instead of \r\n so this would be
						 * the second \n to denote the end of headers*/
                        _state = HTTPParserState.s_headers_almost_done;
                        //goto reexecute;
                        goto reexecute;
                    }

                    c = tokens[ch];

                    if (!c)
                    {
                        _httpErrno = HTTPParserErrno.HPE_INVALID_HEADER_TOKEN;
                        goto error;
                    }

                    if (mHeaderFieldMark == size_t.max)
                    {
                        mHeaderFieldMark = p;
                    }

                    _index = 0;
                    _state = HTTPParserState.s_header_field;

                    switch (c)
                    {
                    case 'c':
                         _headerState = HTTPParserHeaderstates.h_C;
                        break;

                    case 'p':
                         _headerState = HTTPParserHeaderstates.h_matching_proxy_connection;
                        break;

                    case 't':
                         _headerState = HTTPParserHeaderstates.h_matching_transfer_encoding;
                        break;

                    case 'u':
                         _headerState = HTTPParserHeaderstates.h_matching_upgrade;
                        break;

                    default:
                         _headerState = HTTPParserHeaderstates.h_general;
                        break;
                    }
                    break;
                }

            case HTTPParserState.s_header_field:
                {
                    const long start = p;
                    for (; p < maxP; p++)
                    {
                        ch = data[p];
                        c = tokens[ch];

                        if (!c)
                            break;

                        switch ( _headerState)
                        {
                        case HTTPParserHeaderstates.h_general:
                            break;

                        case HTTPParserHeaderstates.h_C:
                            _index++;
                             _headerState = (
                                c == 'o' ? HTTPParserHeaderstates.h_CO
                                : HTTPParserHeaderstates.h_general);
                            break;

                        case HTTPParserHeaderstates.h_CO:
                            _index++;
                             _headerState = (
                                c == 'n' ? HTTPParserHeaderstates.h_CON
                                : HTTPParserHeaderstates.h_general);
                            break;

                        case HTTPParserHeaderstates.h_CON:
                            _index++;
                            switch (c)
                            {
                            case 'n':
                                 _headerState = HTTPParserHeaderstates.h_matching_connection;
                                break;
                            case 't':
                                 _headerState = HTTPParserHeaderstates.h_matching_content_length;
                                break;
                            default:
                                 _headerState = HTTPParserHeaderstates.h_general;
                                break;
                            }
                            break;

                            /* connection */

                        case HTTPParserHeaderstates.h_matching_connection:
                            _index++;
                            if (_index > CONNECTION.length || c != CONNECTION[_index])
                            {
                                 _headerState = HTTPParserHeaderstates.h_general;
                            }
                            else if (_index == CONNECTION.length - 1)
                            {
                                 _headerState = HTTPParserHeaderstates.h_connection;
                            }
                            break;

                            /* proxy-connection */

                        case HTTPParserHeaderstates.h_matching_proxy_connection:
                            _index++;
                            if (_index > PROXY_CONNECTION.length || c != PROXY_CONNECTION[_index])
                            {
                                 _headerState = HTTPParserHeaderstates.h_general;
                            }
                            else if (_index == PROXY_CONNECTION.length)
                            {
                                 _headerState = HTTPParserHeaderstates.h_connection;
                            }
                            break;

                            /* content-length */

                        case HTTPParserHeaderstates.h_matching_content_length:
                            _index++;
							if (_index > CONTENT_LENGTH.length || c != CONTENT_LENGTH[_index])
                            {
                                 _headerState = HTTPParserHeaderstates.h_general;
                            }
							else if (_index == CONTENT_LENGTH.length - 1)
                            {
                                if (_flags & HTTPParserFlags.F_CONTENTLENGTH)
                                {
                                    _httpErrno = HTTPParserErrno.HPE_UNEXPECTED_CONTENT_LENGTH;
                                    goto error;
                                }
                                 _headerState = HTTPParserHeaderstates.h_content_length;
                                _flags |= HTTPParserFlags.F_CONTENTLENGTH;
                            }
                            break;

                            /* transfer-encoding */

                        case HTTPParserHeaderstates.h_matching_transfer_encoding:
                            _index++;
                            if (_index > TRANSFER_ENCODING.length || c != TRANSFER_ENCODING[_index])
                            {
                                 _headerState = HTTPParserHeaderstates.h_general;
                            }
                            else if (_index == TRANSFER_ENCODING.length - 1)
                            {
                                 _headerState = HTTPParserHeaderstates.h_transfer_encoding;
                            }
                            break;

                            /* upgrade */

                        case HTTPParserHeaderstates.h_matching_upgrade:
                            _index++;
                            if (_index > UPGRADE.length || c != UPGRADE[_index])
                            {
                                 _headerState = HTTPParserHeaderstates.h_general;
                            }
                            else if (_index == UPGRADE.length - 1)
                            {
                                 _headerState = HTTPParserHeaderstates.h_upgrade;
                            }
                            break;

                        case HTTPParserHeaderstates.h_connection:
                        case HTTPParserHeaderstates.h_content_length:
                        case HTTPParserHeaderstates.h_transfer_encoding:
                        case HTTPParserHeaderstates.h_upgrade:
                            if (
                                    ch != ' ')
                                 _headerState = HTTPParserHeaderstates.h_general;
                            break;

                        default:
                            assert(false, "Unknown  _headerState");
                            //	break;
                        }
                    }

                    //COUNT_HEADER_SIZE(p - start);
                    _nread += (p - start);
                    if (_nread > _maxHeaderSize)
                    {
                        _httpErrno = HTTPParserErrno.HPE_HEADER_OVERFLOW;
                        goto error;
                    }

                    if (p == maxP)
                    {
                        --p;
                        break;
                    }

                    if (ch == ':')
                    {
                        _state = HTTPParserState.s_header_value_discard_ws;
                        mixin(CALLBACK_DATA("HeaderField"));
                        break;
                    }

                    _httpErrno = HTTPParserErrno.HPE_INVALID_HEADER_TOKEN;
                    goto error;
                }

            case HTTPParserState.s_header_value_discard_ws:
                if (ch == ' ' || ch == '\t')
                    break;

                if (ch == CR)
                {
                    _state = HTTPParserState.s_header_value_discard_ws_almost_done;
                    break;
                }

                if (ch == LF)
                {
                    _state = HTTPParserState.s_header_value_discard_lws;
                    break;
                }
                goto case;
                /* FALLTHROUGH */

            case HTTPParserState.s_header_value_start:
                {
                    //MARK(header_value);
                    if (mHeaderValueMark == size_t.max)
                    {
                        mHeaderValueMark = p;
                    }
                    _state = HTTPParserState.s_header_value;
                    _index = 0;

                    c = ch | 0x20; //LOWER(ch);

                    switch ( _headerState)
                    {
                    case HTTPParserHeaderstates.h_upgrade:
                        _flags |= HTTPParserFlags.F_UPGRADE;
                         _headerState = HTTPParserHeaderstates.h_general;
                        break;

                    case HTTPParserHeaderstates.h_transfer_encoding:
                        /* looking for 'Transfer-Encoding: chunked' */
                        if ('c' == c)
                        {
                             _headerState = HTTPParserHeaderstates
                                .h_matching_transfer_encoding_chunked;
                        }
                        else
                        {
                             _headerState = HTTPParserHeaderstates.h_general;
                        }
                        break;

                    case HTTPParserHeaderstates.h_content_length:
                        if (!mixin(IS_NUM("ch")))
                        {
                            _httpErrno = HTTPParserErrno.HPE_INVALID_CONTENT_LENGTH;
                            goto error;
                        }

                        _contentLength = ch - '0';
                        break;

                    case HTTPParserHeaderstates.h_connection:
                        /* looking for 'Connection: keep-alive' */
                        if (c == 'k')
                        {
                             _headerState = HTTPParserHeaderstates.h_matching_connection_keep_alive;
                            _keepAlive = 0x01;
                            /* looking for 'Connection: close' */
                        }
                        else if (c == 'c')
                        {
                             _headerState = HTTPParserHeaderstates.h_matching_connection_close;
							_keepAlive = 0x02;
                        }
                        else if (c == 'u')
                        {
                             _headerState = HTTPParserHeaderstates.h_matching_connection_upgrade;
							_keepAlive = 0x03;
                        }
                        else
                        {
                             _headerState = HTTPParserHeaderstates.h_matching_connection_token;
							_keepAlive = 0x04;
                        }
                        break;

                        /* Multi-value `Connection` header */
                    case HTTPParserHeaderstates.h_matching_connection_token_start:
                        break;

                    default:
                         _headerState = HTTPParserHeaderstates.h_general;
                        break;
                    }
                    break;
                }

            case HTTPParserState.s_header_value: //BUG，找不到结束
            {
                    const long start = p;
                    auto h_state =  _headerState;
                    for (; p < maxP; p++)
                    {
                        ch = data[p];
                        if (ch == CR)
                        {
                            _state = HTTPParserState.s_header_almost_done;
                             _headerState = h_state;
                            mixin(CALLBACK_DATA("HeaderValue"));
                            break;
                        }

                        if (ch == LF)
                        {
                            _state = HTTPParserState.s_header_almost_done;
                            //COUNT_HEADER_SIZE(p - start);
                            _nread += (p - start);
                            if (_nread > _maxHeaderSize)
                            {
                                _httpErrno = HTTPParserErrno.HPE_HEADER_OVERFLOW;
                                goto error;
                            }
                             _headerState = h_state;
                            mixin(CALLBACK_DATA_NOADVANCE("HeaderValue"));
                            goto reexecute;
                        }

                        if (!_lenientHttpHeaders && !(ch == CR || ch == LF
                                || ch == 9 || (ch > 31 && ch != 127)))
                        {
                            _httpErrno = HTTPParserErrno.HPE_INVALID_HEADER_TOKEN;
                            goto error;
                        }

                        c = ch | 0x20; //LOWER(ch);

                        switch (h_state)
                        {
                        case HTTPParserHeaderstates.h_general:
                            {
                                import std.string;
                                import core.stdc.string;

                                size_t limit = maxP - p;

                                limit = (limit < _maxHeaderSize ? limit : _maxHeaderSize); //MIN(limit, TTPConfig.instance.MaxHeaderSize);
                                auto str =  data[p .. maxP];
                                auto tptr = cast(ubyte *)memchr(str.ptr, CR, str.length);
                                auto p_cr = tptr - str.ptr;//str._indexOf(CR); // memchr(p, CR, limit);
                                tptr = cast(ubyte *)memchr(str.ptr, LF, str.length);
                                auto p_lf = tptr - str.ptr ;//str._indexOf(LF); // memchr(p, LF, limit);
                                ++p_cr;
                                ++p_lf;
                                if (p_cr > 0)
                                {
                                    if (p_lf > 0 && p_cr >= p_lf)
                                        p += p_lf;
                                    else
                                        p += p_cr;
                                }
                                else if (p_lf > 0)
                                {
                                    p += p_lf;
                                }
                                else
                                {
                                    p = maxP;
                                }
                                p -= 2;

                                break;
                            }

                        case HTTPParserHeaderstates.h_connection:
                        case HTTPParserHeaderstates.h_transfer_encoding:
                            assert(0,
                                "Shouldn't get here.");
                            //break;

                        case HTTPParserHeaderstates.h_content_length:
                            {
                                ulong t;

                                if (ch == ' ')
                                    break;

                                if (!mixin(IS_NUM("ch")))
                                {
                                    _httpErrno = HTTPParserErrno.HPE_INVALID_CONTENT_LENGTH;
                                     _headerState = h_state;
                                    goto error;
                                }

                                t = _contentLength;
                                t *= 10;
                                t += ch - '0';

                                /* Overflow? Test against a conservative limit for simplicity. */
                                if ((ulong.max - 10) / 10 < _contentLength)
                                {
                                    _httpErrno = HTTPParserErrno.HPE_INVALID_CONTENT_LENGTH;
                                     _headerState = h_state;
                                    goto error;
                                }

                                _contentLength = t;
                                break;
                            }

                            /* Transfer-Encoding: chunked */
                        case HTTPParserHeaderstates.h_matching_transfer_encoding_chunked:
                            _index++;
                            if (_index > CHUNKED.length || c != CHUNKED[_index])
                            {
                                h_state = HTTPParserHeaderstates.h_general;
                            }
                            else if (_index == CHUNKED.length - 1)
                            {
                                h_state = HTTPParserHeaderstates.h_transfer_encoding_chunked;
                            }
                            break;

                        case HTTPParserHeaderstates.h_matching_connection_token_start:
                            /* looking for 'Connection: keep-alive' */
                            if (c == 'k')
                            {
                                h_state = HTTPParserHeaderstates.h_matching_connection_keep_alive;
                                /* looking for 'Connection: close' */
                            }
                            else if (c == 'c')
                            {
                                h_state = HTTPParserHeaderstates.h_matching_connection_close;
                            }
                            else if (c == 'u')
                            {
                                h_state = HTTPParserHeaderstates.h_matching_connection_upgrade;
                            }
                            else if (tokens[c])
                            {
                                h_state = HTTPParserHeaderstates.h_matching_connection_token;
                            }
                            else if (c == ' ' || c == '\t')
                            {
                                /* Skip lws */
                            }
                            else
                            {
                                h_state = HTTPParserHeaderstates.h_general;
                            }
                            break;

                            /* looking for 'Connection: keep-alive' */
                        case HTTPParserHeaderstates.h_matching_connection_keep_alive:
                            _index++;
                            if (_index > KEEP_ALIVE.length || c != KEEP_ALIVE[_index])
                            {
                                h_state = HTTPParserHeaderstates.h_matching_connection_token;
                            }
                            else if (_index == KEEP_ALIVE.length - 1)
                            {
                                h_state = HTTPParserHeaderstates.h_connection_keep_alive;
                            }
                            break;

                            /* looking for 'Connection: close' */
                        case HTTPParserHeaderstates.h_matching_connection_close:
                            _index++;
                            if (_index > CLOSE.length || c != CLOSE[_index])
                            {
                                h_state = HTTPParserHeaderstates.h_matching_connection_token;
                            }
                            else if (_index == CLOSE.length - 1)
                            {
                                h_state = HTTPParserHeaderstates.h_connection_close;
                            }
                            break;

                            /* looking for 'Connection: upgrade' */
                        case HTTPParserHeaderstates.h_matching_connection_upgrade:
                            _index++;
                            if (_index > UPGRADE.length || c != UPGRADE[_index])
                            {
                                h_state = HTTPParserHeaderstates.h_matching_connection_token;
                            }
                            else if (_index == UPGRADE.length - 1)
                            {
                                h_state = HTTPParserHeaderstates.h_connection_upgrade;
                            }
                            break;

                        case HTTPParserHeaderstates.h_matching_connection_token:
                            if (ch == ',')
                            {
                                h_state = HTTPParserHeaderstates.h_matching_connection_token_start;
                                _index = 0;
                            }
                            break;

                        case HTTPParserHeaderstates.h_transfer_encoding_chunked:
                            if (
                                    ch != ' ')
                                h_state = HTTPParserHeaderstates.h_general;
                            break;

                        case HTTPParserHeaderstates.h_connection_keep_alive:
                        case HTTPParserHeaderstates.h_connection_close:
                        case HTTPParserHeaderstates.h_connection_upgrade:
                            if (ch == ',')
                            {
                                if (h_state == HTTPParserHeaderstates.h_connection_keep_alive)
                                {
                                    _flags |= HTTPParserFlags.F_CONNECTION_KEEP_ALIVE;
                                }
                                else if (h_state == HTTPParserHeaderstates.h_connection_close)
                                {
                                    _flags |= HTTPParserFlags.F_CONNECTION_CLOSE;
                                }
                                else if (h_state == HTTPParserHeaderstates.h_connection_upgrade)
                                {
                                    _flags |= HTTPParserFlags.F_CONNECTION_UPGRADE;
                                }
                                h_state = HTTPParserHeaderstates.h_matching_connection_token_start;
                                _index = 0;
                            }
                            else if (ch != ' ')
                            {
                                h_state = HTTPParserHeaderstates.h_matching_connection_token;
                            }
                            break;

                        default:
                            _state = HTTPParserState.s_header_value;
                            h_state = HTTPParserHeaderstates.h_general;
                            break;
                        }
                    }

                     _headerState = h_state;

                    //COUNT_HEADER_SIZE(p - start);
                    _nread += (p - start);
                    if (_nread > _maxHeaderSize)
                    {
                        _httpErrno = HTTPParserErrno.HPE_HEADER_OVERFLOW;
                        goto error;
                    }

                    if (p == maxP)
                        --p;
                    break;
                }

            case HTTPParserState.s_header_almost_done:
                {
                    if (ch != LF)
                    {
                        _httpErrno = HTTPParserErrno.HPE_LF_EXPECTED;
                        goto error;
                    }

                    _state = HTTPParserState.s_header_value_lws;
                    break;
                }

            case HTTPParserState.s_header_value_lws:
                {
                    if (ch == ' ' || ch == '\t')
                    {
                        _state = HTTPParserState.s_header_value_start;
                        goto reexecute;
                    }

                    /* finished the header */
                    switch ( _headerState)
                    {
                    case HTTPParserHeaderstates.h_connection_keep_alive:
                        _flags |= HTTPParserFlags.F_CONNECTION_KEEP_ALIVE;
                        break;
                    case HTTPParserHeaderstates.h_connection_close:
                        _flags |= HTTPParserFlags.F_CONNECTION_CLOSE;
                        break;
                    case HTTPParserHeaderstates.h_transfer_encoding_chunked:
                        _flags |= HTTPParserFlags.F_CHUNKED;
                        break;
                    case HTTPParserHeaderstates.h_connection_upgrade:
                        _flags |= HTTPParserFlags.F_CONNECTION_UPGRADE;
                        break;
                    default:
                        break;
                    }

                    _state = HTTPParserState.s_header_field_start;
                    goto reexecute;
                }

            case HTTPParserState.s_header_value_discard_ws_almost_done:
                {
                    mixin(STRICT_CHECK("ch != LF"));
                    _state = HTTPParserState.s_header_value_discard_lws;
                    break;
                }

            case HTTPParserState.s_header_value_discard_lws:
                {
                    if (ch == ' ' || ch == '\t')
                    {
                        _state = HTTPParserState.s_header_value_discard_ws;
                        break;
                    }
                    else
                    {
                        switch ( _headerState)
                        {
                        case HTTPParserHeaderstates.h_connection_keep_alive:
                            _flags |= HTTPParserFlags.F_CONNECTION_KEEP_ALIVE;
                            break;
                        case HTTPParserHeaderstates.h_connection_close:
                            _flags |= HTTPParserFlags.F_CONNECTION_CLOSE;
                            break;
                        case HTTPParserHeaderstates.h_connection_upgrade:
                            _flags |= HTTPParserFlags.F_CONNECTION_UPGRADE;
                            break;
                        case HTTPParserHeaderstates.h_transfer_encoding_chunked:
                            _flags |= HTTPParserFlags.F_CHUNKED;
                            break;
                        default:
                            break;
                        }

                        /* header value was empty */
                        //MARK(header_value);
                        if (mHeaderValueMark == size_t.max)
                        {
                            mHeaderValueMark = p;
                        }
                        _state = HTTPParserState.s_header_field_start;
                        mixin(CALLBACK_DATA_NOADVANCE("HeaderValue"));
                        goto reexecute;
                    }
                }
                //TODO	
            case HTTPParserState.s_headers_almost_done:
                {
                    mixin(STRICT_CHECK("ch != LF"));

                    if (_flags & HTTPParserFlags.F_TRAILING)
                    {
                        /* End of a chunked request */
                        _state = HTTPParserState.s_message_done;
                        mixin(CALLBACK_NOTIFY_NOADVANCE("ChunkComplete"));
                        goto reexecute;
                    }

                    /* Cannot use chunked encoding and a content-length header together
					 per the HTTP specification. */
                    if ((_flags & HTTPParserFlags.F_CHUNKED)
                            && (_flags & HTTPParserFlags.F_CONTENTLENGTH))
                    {
                        _httpErrno = HTTPParserErrno.HPE_UNEXPECTED_CONTENT_LENGTH;
                        goto error;
                    }

                    _state = HTTPParserState.s_headers_done;

                    /* Set this here so that on_headers_complete() callbacks can see it */
                    _upgrade = (
                        (_flags & (HTTPParserFlags.F_UPGRADE | HTTPParserFlags.F_CONNECTION_UPGRADE)) == (
                        HTTPParserFlags.F_UPGRADE | HTTPParserFlags.F_CONNECTION_UPGRADE)
                        || _method == HTTPMethod.HTTP_CONNECT);
                    {
						if(_keepAlive == 0x00 && _httpMinor == 0 && _httpMajor == 1){
							_keepAlive = 0x02;
						}else {
							_keepAlive = 0x01;
						}
                        if (_onHeadersComplete !is null)
                        {
                            _onHeadersComplete(this);
                            //error("_onHeadersComplete " , errorString);
                            //error("handleIng  " , handleIng);
                            //error("handleIng  " , skipBody);
                            //error("state  " , state);
                            if (!handleIng)
                            {
                                _httpErrno = HTTPParserErrno.HPE_CB_HeadersComplete;
                                return p; /* Error */
                            }
                            if (skipBody)
                                _flags |= HTTPParserFlags.F_SKIPBODY;

                        }

                    }

                    goto reexecute;
                }

            case HTTPParserState.s_headers_done:
                {
                    int hasBody;
                    mixin(STRICT_CHECK("ch != LF"));

                    _nread = 0;
                    //int chunked = _flags & HTTPParserFlags.F_CHUNKED ;
                    //error("s_headers_done is chunked : ", chunked);
                    hasBody = _flags & HTTPParserFlags.F_CHUNKED
                        || (_contentLength > 0 && _contentLength != ULLONG_MAX);
                    if (_upgrade && (_method == HTTPMethod.HTTP_CONNECT
                            || (_flags & HTTPParserFlags.F_SKIPBODY) || !hasBody))
                    {
                        /* Exit, the rest of the message is in a different protocol. */
                        _state = mixin(NEW_MESSAGE);
                        mixin(CALLBACK_NOTIFY("MessageComplete"));
                        return (p + 1);
                    }

                    if (_flags & HTTPParserFlags.F_SKIPBODY)
                    {
                        _state = mixin(NEW_MESSAGE);
						mixin(CALLBACK_NOTIFY("MessageComplete"));
                    }
                    else if (_flags & HTTPParserFlags.F_CHUNKED)
                    {
                        /* chunked encoding - ignore Content-Length header */
                        _state = HTTPParserState.s_chunk_size_start;
                    }
                    else
                    {
                        if (_contentLength == 0)
                        {
                            /* Content-Length header given but zero: Content-Length: 0\r\n */
                            _state = mixin(NEW_MESSAGE);
							mixin(CALLBACK_NOTIFY("MessageComplete"));
                        }
                        else if (_contentLength != ULLONG_MAX)
                        {
                            /* Content-Length header given and non-zero */
                            _state = HTTPParserState.s_body_identity;
                        }
                        else
                        {
                            if (!httpMessageNeedsEof())
                            {
                                /* Assume content-length 0 - read the next */
                                _state = mixin(NEW_MESSAGE);
								mixin(CALLBACK_NOTIFY("MessageComplete"));
                            }
                            else
                            {
                                /* Read body until EOF */
                                _state = HTTPParserState.s_body_identity_eof;
                            }
                        }
                    }

                    break;
                }

            case HTTPParserState.s_body_identity:
                {
                    ulong to_read = _contentLength < cast(ulong)(maxP - p) ? _contentLength : cast(
                        ulong)(maxP - p);

                    assert(_contentLength != 0 && _contentLength != ULLONG_MAX);

                    /* The difference between advancing _contentLength and p is because
					 * the latter will automaticaly advance on the next loop iteration.
					 * Further, if _contentLength ends up at 0, we want to see the last
					 * byte again for our message complete callback.
					 */
                    //MARK(body);

                    if (mBodyMark == size_t.max)
                    {
                        mBodyMark = p;
                    }
                    _contentLength -= to_read;
                    p += to_read - 1;

                    if (_contentLength == 0)
                    {
                        _state = HTTPParserState.s_message_done;

                        /* Mimic CALLBACK_DATA_NOADVANCE() but with one extra byte.
						 *
						 * The alternative to doing this is to wait for the next byte to
						 * trigger the data callback, just as in every other case. The
						 * problem with this is that this makes it difficult for the test
						 * harness to distinguish between complete-on-EOF and
						 * complete-on-length. It's not clear that this distinction is
						 * important for applications, but let's keep it for now.
						 */
                        if (mBodyMark != size_t.max && _onBody !is null)
                        {
                            ubyte[] _data = data[mBodyMark .. p + 1];
                            _onBody(this, _data, true);
                            if (!handleIng)
                            {
                                _httpErrno = HTTPParserErrno.HPE_CB_Body;
                                return p + 1;
                            }
                        }
                        mBodyMark = size_t.max;
                        goto reexecute;
                    }

                    break;
                }

                /* read until EOF */
            case HTTPParserState.s_body_identity_eof:
                //MARK(body);
                if (mBodyMark == size_t.max)
                {
                    mBodyMark = p;
                }

                p = maxP - 1;

                break;

            case HTTPParserState.s_message_done:
                _state = mixin(NEW_MESSAGE);
				mixin(CALLBACK_NOTIFY("MessageComplete"));
                if (_upgrade)
                {
                    /* Exit, the rest of the message is in a different protocol. */
                    return (p + 1);
                }
                break;

            case HTTPParserState.s_chunk_size_start:
                {
                    assert(_nread == 1);
                    assert(_flags & HTTPParserFlags.F_CHUNKED);

                    unhexVal = unhex[ch];
                    if (unhexVal == -1)
                    {
                        _httpErrno = HTTPParserErrno.HPE_INVALID_CHUNK_SIZE;
                        goto error;
                    }

                    _contentLength = unhexVal;
                    _state = HTTPParserState.s_chunk_size;
                    break;
                }

            case HTTPParserState.s_chunk_size:
                {
                    ulong t;

                    assert(_flags & HTTPParserFlags.F_CHUNKED);

                    if (ch == CR)
                    {
                        _state = HTTPParserState.s_chunk_size_almost_done;
                        break;
                    }

                    unhexVal = unhex[ch];

                    if (unhexVal == -1)
                    {
                        if (ch == ';' || ch == ' ')
                        {
                            _state = HTTPParserState.s_chunk_parameters;
                            break;
                        }

                        _httpErrno = HTTPParserErrno.HPE_INVALID_CHUNK_SIZE;
                        goto error;
                    }

                    t = _contentLength;
                    t *= 16;
                    t += unhexVal;

                    /* Overflow? Test against a conservative limit for simplicity. */
                    if ((ULLONG_MAX - 16) / 16 < _contentLength)
                    {
                        _httpErrno = HTTPParserErrno.HPE_INVALID_CONTENT_LENGTH;
                        goto error;
                    }

                    _contentLength = t;
                    break;
                }

            case HTTPParserState.s_chunk_parameters:
                {
                    assert(_flags & HTTPParserFlags.F_CHUNKED);
                    /* just ignore this shit. TODO check for overflow */
                    if (ch == CR)
                    {
                        _state = HTTPParserState.s_chunk_size_almost_done;
                        break;
                    }
                    break;
                }

            case HTTPParserState.s_chunk_size_almost_done:
                {
                    assert(_flags & HTTPParserFlags.F_CHUNKED);
                    mixin(STRICT_CHECK("ch != LF"));

                    _nread = 0;

                    if (_contentLength == 0)
                    {
                        _flags |= HTTPParserFlags.F_TRAILING;
                        _state = HTTPParserState.s_header_field_start;
                    }
                    else
                    {
                        _state = HTTPParserState.s_chunk_data;
                    }
                    mixin(CALLBACK_NOTIFY("ChunkHeader"));
                    break;
                }

            case HTTPParserState.s_chunk_data:
                {
                    ulong to_read = _contentLength < cast(ulong)(maxP - p) ? _contentLength : cast(
                        ulong)(maxP - p);

                    assert(_flags & HTTPParserFlags.F_CHUNKED);
                    assert(_contentLength != 0 && _contentLength != ULLONG_MAX);

                    /* See the explanation in s_body_identity for why the content
					 * length and data pointers are managed this way.
					 */
                    //MARK(body);
                    if (mBodyMark == size_t.max)
                    {
                        mBodyMark = p;
                    }
                    _contentLength -= to_read;
                    p += to_read - 1;

                    if (_contentLength == 0)
                    {
                        _state = HTTPParserState.s_chunk_data_almost_done;
                    }

                    break;
                }

            case HTTPParserState.s_chunk_data_almost_done:
                assert(_flags & HTTPParserFlags.F_CHUNKED);
                assert(_contentLength == 0);
                mixin(STRICT_CHECK("ch != CR"));
                _state = HTTPParserState.s_chunk_data_done;
                mixin(CALLBACK_DATA("Body"));
                break;

            case HTTPParserState.s_chunk_data_done:
                assert(_flags & HTTPParserFlags.F_CHUNKED);
                mixin(STRICT_CHECK("ch != LF"));
                _nread = 0;
                _state = HTTPParserState.s_chunk_size_start;
                mixin(CALLBACK_NOTIFY("ChunkComplete"));
                break;

            default:
                //assert(0 && "unhandled state");
                _httpErrno = HTTPParserErrno.HPE_INVALID_INTERNAL_STATE;
                goto error;
            }
        }

        assert(
            (
            (mHeaderFieldMark != size_t.max ? 1 : 0) + (mHeaderValueMark != size_t.max ? 1 : 0) + (
            mUrlMark != size_t.max ? 1 : 0) + (mBodyMark != size_t.max ? 1 : 0) + (
            mStatusMark != size_t.max ? 1 : 0)) <= 1);

        mixin(CALLBACK_DATA_NOADVANCE("HeaderField")); //最后没找到
        mixin(CALLBACK_DATA_NOADVANCE("HeaderValue"));
        mixin(CALLBACK_DATA_NOADVANCE("Url"));
        mixin(CALLBACK_DATA_NOADVANCE("Body"));
        mixin(CALLBACK_DATA_NOADVANCE("Status"));

        return data.length;

    error:
        if (_httpErrno == HTTPParserErrno.HPE_OK)
        {
            _httpErrno = HTTPParserErrno.HPE_UNKNOWN;
        }

        return p;
    }

private:
    HTTPParserType _type = HTTPParserType.HTTP_BOTH;
    HTTPParserFlags _flags = HTTPParserFlags.F_ZERO;
	HTTPParserState _state = HTTPParserState.s_start_req_or_res;
    HTTPParserHeaderstates  _headerState;
    uint _index;
    uint _lenientHttpHeaders;
    uint _nread;
    ulong _contentLength;
    ushort _httpMajor;
    ushort _httpMinor;
    uint _statusCode; /* responses only */
    HTTPMethod _method; /* requests only */
    HTTPParserErrno _httpErrno = HTTPParserErrno.HPE_OK;
    /* 1 = Upgrade header was present and the parser has exited because of that.
	 * 0 = No upgrade header present.
	 * Should be checked when http_parser_execute() returns in addition to
	 * error checking.
	 */
    bool _upgrade;

    bool _isHandle = false;

    bool _skipBody = false;

	ubyte _keepAlive = 0x00;

    uint _maxHeaderSize = 4096;

protected:
    @property type(HTTPParserType ty)
    {
        _type = ty;
    }

    pragma(inline)
    bool httpMessageNeedsEof()
    {
        if (type == HTTPParserType.HTTP_REQUEST)
        {
            return false;
        }

        /* See RFC 2616 section 4.4 */
        if (_statusCode / 100 == 1 || /* 1xx e.g. Continue */
                _statusCode == 204 || /* No Content */
                _statusCode == 304
                || /* Not Modified */
                _flags & HTTPParserFlags.F_SKIPBODY)
        { /* response to a HEAD request */
            return false;
        }

        if ((_flags & HTTPParserFlags.F_CHUNKED) || _contentLength != ULLONG_MAX)
        {
            return false;
        }

        return true;
    }

    pragma(inline)
    bool httpShouldKeepAlive()
    {
        if (_httpMajor > 0 && _httpMinor > 0)
        {
            /* HTTP/1.1 */
            if (_flags & HTTPParserFlags.F_CONNECTION_CLOSE)
            {
                return false;
            }
        }
        else
        {
            /* HTTP/1.0 or earlier */
            if (!(_flags & HTTPParserFlags.F_CONNECTION_KEEP_ALIVE))
            {
                return false;
            }
        }

        return !httpMessageNeedsEof();
    }

    HTTPParserState parseURLchar(HTTPParserState s, ubyte ch)
    {
        if (ch == ' ' || ch == '\r' || ch == '\n')
        {
            return HTTPParserState.s_dead;
        }

        version (HTTP_PARSER_STRICT)
        {
            if (ch == '\t' || ch == '\f')
            {
                return s_dead;
            }
        }

        switch (s)
        {
        case HTTPParserState.s_req_spaces_before_url:
            /* Proxied requests are followed by scheme of an absolute URI (alpha).
				 * All methods except CONNECT are followed by '/' or '*'.
				 */

            if (ch == '/' || ch == '*')
            {
                return HTTPParserState.s_req_path;
            }

            if (mixin(IS_ALPHA("ch")))
            {
                return HTTPParserState.s_req_schema;
            }

            break;

        case HTTPParserState.s_req_schema:
            if (mixin(IS_ALPHA("ch")))
            {
                return s;
            }

            if (ch == ':')
            {
                return HTTPParserState.s_req_schema_slash;
            }

            break;

        case HTTPParserState.s_req_schema_slash:
            if (ch == '/')
            {
                return HTTPParserState.s_req_schema_slash_slash;
            }

            break;

        case HTTPParserState.s_req_schema_slash_slash:
            if (ch == '/')
            {
                return HTTPParserState.s_req_server_start;
            }

            break;

        case HTTPParserState.s_req_server_with_at:
            if (ch == '@')
            {
                return HTTPParserState.s_dead;
            }
            goto case;
            /* FALLTHROUGH */
        case HTTPParserState.s_req_server_start:
        case HTTPParserState.s_req_server:
            {
                if (ch == '/')
                {
                    return HTTPParserState.s_req_path;
                }

                if (ch == '?')
                {
                    return HTTPParserState.s_req_query_string_start;
                }

                if (ch == '@')
                {
                    return HTTPParserState.s_req_server_with_at;
                }

                if (IS_USERINFO_CHAR2(ch) || ch == '[' || ch == ']')
                {
                    return HTTPParserState.s_req_server;
                }
            }
            break;

        case HTTPParserState.s_req_path:
            {
                if (mixin(IS_URL_CHAR("ch")))
                {
                    return s;
                }

                switch (ch)
                {
                case '?':
                    return HTTPParserState.s_req_query_string_start;

                case '#':
                    return HTTPParserState.s_req_fragment_start;
                default:
                    break;
                }
                break;
            }

        case HTTPParserState.s_req_query_string_start:
        case HTTPParserState.s_req_query_string:
            {
                if (mixin(IS_URL_CHAR("ch")))
                {
                    return HTTPParserState.s_req_query_string;
                }

                switch (ch)
                {
                case '?':
                    /* allow extra '?' in query string */
                    return HTTPParserState.s_req_query_string;

                case '#':
                    return HTTPParserState.s_req_fragment_start;
                default:
                    break;
                }
                break;
            }

        case HTTPParserState.s_req_fragment_start:
            {
                if (mixin(IS_URL_CHAR("ch")))
                {
                    return HTTPParserState.s_req_fragment;
                }

                switch (ch)
                {
                case '?':
                    return HTTPParserState.s_req_fragment;

                case '#':
                    return s;
                default:
                    break;
                }
                break;
            }

        case HTTPParserState.s_req_fragment:
            {
                if (mixin(IS_URL_CHAR("ch")))
                {
                    return s;
                }

                switch (ch)
                {
                case '?':
                case '#':
                    return s;
                default:
                    break;
                }
                break;
            }
        default:
            break;
        }

        /* We should never fall out of the switch above unless there's an error */
        return HTTPParserState.s_dead;
    }

}

private:

pragma(inline,true)
bool IS_USERINFO_CHAR2(ubyte c)
{
    bool alpha = mixin(IS_ALPHA("c"));
    bool sum = mixin(IS_NUM("c"));
    bool b1 = (c == '%' || c == ';' || c == ':' || c == '&' || c == '='
        || c == '+' || c == '$' || c == ',');
    bool b2 = (c == '-' || '_' == c || '.' == c || '!' == c || '~' == c || '*' == c
        || '\'' == c || '(' == c || ')' == c);
    return (b2 || b1 || sum || alpha);
}

string IS_USERINFO_CHAR(string c)
{
    return "( " ~ IS_ALPHA(c) ~ " || " ~ IS_NUM(c) ~ " || " ~ c ~ " == '%' || " ~ c ~ " == ';' || " ~ c ~ " == ':' || " ~ c ~ " == '&' || " ~ c ~ " == '=' ||  " ~ c ~ " == '+' || " ~ c ~ " == '$' || " ~ c ~ " == ','" ~ c ~ " == '-' || '_' == " ~ c ~ "|| '.' == " ~ c ~ "|| '!' == " ~ c ~ "|| '~' == " ~ c ~ "|| '*' == " ~ c ~ "|| '\'' == " ~ c ~ "|| '(' == " ~ c ~ "|| ')' == " ~ c ~ ")";
}

string STRICT_CHECK(string cond)
{
    string code = "if (";
    code = code ~ cond ~ ") {                                                   
			_httpErrno = HTTPParserErrno.HPE_STRICT;                                     
			goto error;                                           
		}  ";
    return code;
}

//	string IS_MARK(string c) { return "(" ~ c ~ " == '-' || " ~ c ~ " == '_' || "~ c ~ " == '.' || " ~ c ~ " == '!' || " ~ c ~ " == '~' ||  " ~ c ~ " == '*' ||  " ~ c ~ " == '\'' || " ~ c ~ " == '(' || " ~ c ~ " == ')')";}
string IS_NUM(string c)
{
    return "(" ~ c ~ " >= '0' &&  " ~ c ~ "  <= '9')";
}

string IS_ALPHA(string c)
{
    return "((" ~ c ~ "| 0x20) >= 'a' && (" ~ c ~ " | 0x20) <= 'z')";
}

string IS_URL_CHAR(string c)
{
    return "(!!(cast(uint) (normal_url_char[cast(uint) (" ~ c ~ ") >> 3] ) &                  
				(1 << (cast(uint)" ~ c ~ " & 7))))";
}

enum NEW_MESSAGE = "httpShouldKeepAlive() ? (type == HTTPParserType.HTTP_REQUEST ? HTTPParserState.s_start_req : HTTPParserState.s_start_res) : HTTPParserState.s_dead";
string CALLBACK_NOTIFY(string code)
{
    string _s = " {if (_on" ~ code ~ " !is null){
               trace(\" CALLBACK_NOTIFY : " ~ code ~ "\");
               _on" ~ code ~ "(this); if(!handleIng){
                _httpErrno = HTTPParserErrno.HPE_CB_" ~ code ~ ";
                return  p + 1;}} }";
    return _s;
}

string CALLBACK_NOTIFY_NOADVANCE(string code)
{
    string _s = " {if (_on" ~ code ~ " != null){
                   trace(\" CALLBACK_NOTIFY_NOADVANCE : " ~ code ~ "\");
	               _on" ~ code ~ "(this); if(!handleIng){
	                _httpErrno = HTTPParserErrno.HPE_CB_" ~ code ~ ";
	                return  p;} }}";
    return _s;
}

string CALLBACK_DATA(string code)
{
    string _s = "{ if( m" ~ code ~ "Mark != size_t.max && _on" ~ code ~ " !is null){
                ulong len = (p - m" ~ code ~ "Mark) ;
                
                if(len > 0) {  
                trace(\"CALLBACK_DATA at  \",__LINE__, \"  " ~ code ~ "\");
                ubyte[]  _data =  data[m" ~ code ~ "Mark..p];
                _on" ~ code ~ "(this,_data,true);
                if (!handleIng){
                    _httpErrno = HTTPParserErrno.HPE_CB_" ~ code ~ ";
                    return  p + 1;}} } m" ~ code ~ "Mark = size_t.max;}";
    return _s;
}

string CALLBACK_DATA_NOADVANCE(string code)
{
	string _s = "{ if(m" ~ code ~ "Mark != size_t.max && _on" ~ code ~ " !is null){
                ulong len = (p - m" ~ code ~ "Mark) ;
                if(len > 0) {  
                trace(\"CALLBACK_DATA_NOADVANCE at  \",__LINE__, \"  " ~ code ~ "\");
                ubyte[]  _data = data[m" ~ code ~ "Mark..p];
                _on" ~ code ~ "(this,_data,false);
                if (!handleIng){
                    _httpErrno = HTTPParserErrno.HPE_CB_" ~ code ~ ";
                return  p;} }}m" ~ code ~ "Mark = size_t.max;}";
    return _s;
}

unittest
{
    import std.stdio;
    import std.functional;

    writeln("\n\n\n");

    void on_message_begin(ref HTTPParser)
    {
        writeln("_onMessageBegin");
        writeln(" ");
    }

	void on_url(ref HTTPParser par, ubyte[] data, bool adv)
    {
        writeln("_onUrl, is NOADVANCE = ", adv);
        writeln("\" ", cast(string) data, " \"");
        writeln("HTTPMethod is = ", par.methodString);
        writeln(" ");
    }

	void on_status(ref HTTPParser par, ubyte[] data, bool adv)
    {
        writeln("_onStatus, is NOADVANCE = ", adv);
        writeln("\" ", cast(string) data, " \"");
        writeln(" ");
    }

	void on_header_field(ref HTTPParser par, ubyte[] data, bool adv)
    {
        static bool frist = true;
        writeln("_onHeaderField, is NOADVANCE = ", adv);
        writeln("len = ", data.length);
        writeln("\" ", cast(string) data, " \"");
        if (frist)
        {
            writeln("\t _httpMajor", par.major);
            writeln("\t _httpMinor", par.minor);
            frist = false;
        }
        writeln(" ");
    }

	void on_header_value(ref HTTPParser par, ubyte[] data, bool adv)
    {
        writeln("_onHeaderValue, is NOADVANCE = ", adv);
        writeln("\" ", cast(string) data, " \"");
        writeln(" ");
    }

	void on_headers_complete(ref HTTPParser par)
    {
        writeln("_onHeadersComplete");
        writeln(" ");
    }

	void on_body(ref HTTPParser par, ubyte[] data, bool adv)
    {
        writeln("_onBody, is NOADVANCE = ", adv);
        writeln("\" ", cast(string) data, " \"");
        writeln(" ");
    }

	void on_message_complete(ref HTTPParser par)
    {
        writeln("_onMessageComplete");
        writeln(" ");
    }

	void on_chunk_header(ref HTTPParser par)
    {
        writeln("_onChunkHeader");
        writeln(" ");
    }

	void on_chunk_complete(ref HTTPParser par)
    {
        writeln("_onChunkComplete");
        writeln(" ");
    }

    string data = "GET /test HTTP/1.1\r\nUser-Agent: curl/7.18.0 (i486-pc-linux-gnu) libcurl/7.18.0 OpenSSL/0.9.8g zlib/1.2.3.3 libidn/1.1\r\nHost:0.0.0.0=5000\r\nAccept: */*\r\n\r\n";
    HTTPParser par = HTTPParser();
    par.onMessageBegin = toDelegate(&on_message_begin);
    par.onMessageComplete = toDelegate(&on_message_complete);
    par.onUrl = toDelegate(&on_url);
    par.onStatus = toDelegate(&on_status);
    par.onHeaderField = toDelegate(&on_header_field);
    par.onHeaderValue = toDelegate(&on_header_value);
    par.onChunkHeader = toDelegate(&on_chunk_header);
    par.onChunkComplete = toDelegate(&on_chunk_complete);
    par.onBody = toDelegate(&on_body);

    ulong len = par.httpParserExecute(cast(ubyte[]) data);
    if (data.length != len)
    {
        writeln("\t error ! ", par.error);
    }
    par.rest(HTTPParserType.HTTP_BOTH);
    data = "POST /post_chunked_all_your_base HTTP/1.1\r\nHost:0.0.0.0=5000\r\nTransfer-Encoding:chunked\r\n\r\n5\r\nhello\r\n";

    auto data2 = "0\r\n\r\n";

    len = par.httpParserExecute(cast(ubyte[]) data);
    if (data.length != len)
    {
        writeln("error1 ! ", par.error);
        writeln("\t error1 ! ", par.errorString);
        return;
    }
    writeln("data 1 is over!");
    len = par.httpParserExecute(cast(ubyte[]) data2);
    writeln("last len = ", len);
    if (data2.length != len)
    {
        writeln("\t error ! ", par.errorString);
        writeln("HTTPMethod is = ", par.methodString);
        writeln("erro!!!!!");
    }
}
