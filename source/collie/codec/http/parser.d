module collie.codec.http.parser;

public import collie.codec.http.parsertype;
import collie.codec.http.config;

/** ubyte[] 为传过去字段里的位置引用，没有数据拷贝，自己使用的时候注意拷贝数据， 
 bool 此段数据是否完结，可能只是数据的一部分。
 */
alias CallBackData = void delegate(HTTPParser, ubyte[], bool);
alias CallBackNotify = void delegate(HTTPParser);

final class HTTPParser
{
    this(HTTPParserType ty = HTTPParserType.HTTP_BOTH, uint maxHeaderSize = 1024)
    {
        rest(ty);
        _maxHeaderSize = maxHeaderSize;
    }

    pragma(inline,true)
    @property type()
    {
        return _type;
    }

    pragma(inline,true)
    @property isUpgrade()
    {
        return upgrade;
    }

    pragma(inline,true)
    @property contentLength()
    {
        return content_length;
    }

    pragma(inline,true)
    @property isChunked()
    {
        return (flags & HTTPParserFlags.F_CHUNKED) == 0 ? false : true;
    }
    //@property status() {return status_code;}
    pragma(inline,true)
    @property error()
    {
        return http_errno;
    }

    pragma(inline,true)
    @property errorString()
    {
        return error_string[http_errno];
    }

    pragma(inline,true)
    @property methodCode()
    {
        return method;
    }

    pragma(inline,true)
    @property methodString()
    {
        return method_strings[method];
    }

    pragma(inline,true)
    @property major()
    {
        return http_major;
    }

    //版本号首位
    pragma(inline,true)
    @property minor()
    {
        return http_minor;
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

    /** 回调函数指定 */
    pragma(inline)
    @property onMessageBegin(CallBackNotify cback)
    {
        _on_message_begin = cback;
    }

    pragma(inline)
    @property onMessageComplete(CallBackNotify cback)
    {
        _on_message_complete = cback;
    }

    pragma(inline)
    @property onHeaderComplete(CallBackNotify cback)
    {
        _on_headers_complete = cback;
    }

    pragma(inline)
    @property onChunkHeader(CallBackNotify cback)
    {
        _on_chunk_header = cback;
    }

    pragma(inline)
    @property onChunkComplete(CallBackNotify cback)
    {
        _on_chunk_complete = cback;
    }

    pragma(inline)
    @property onUrl(CallBackData cback)
    {
        _on_url = cback;
    }

    pragma(inline)
    @property onStatus(CallBackData cback)
    {
        _on_status = cback;
    }

    pragma(inline)
    @property onHeaderField(CallBackData cback)
    {
        _on_header_field = cback;
    }

    pragma(inline)
    @property onHeaderValue(CallBackData cback)
    {
        _on_header_value = cback;
    }

    pragma(inline)
    @property onBody(CallBackData cback)
    {
        _on_body = cback;
    }

    pragma(inline)
    void rest(HTTPParserType ty)
    {
        type = ty;
        state = (
            type == HTTPParserType.HTTP_REQUEST ? HTTPParserState.s_start_req : (
            type == HTTPParserType.HTTP_RESPONSE ? HTTPParserState.s_start_res
            : HTTPParserState.s_start_req_or_res));
        http_errno = HTTPParserErrno.HPE_OK;
        flags = HTTPParserFlags.F_ZERO;
    }

protected:
    CallBackNotify _on_message_begin;

    CallBackNotify _on_headers_complete;

    CallBackNotify _on_message_complete;

    CallBackNotify _on_chunk_header;

    CallBackNotify _on_chunk_complete;

    CallBackData _on_url;

    CallBackData _on_status;

    CallBackData _on_header_field;

    CallBackData _on_header_value;

    CallBackData _on_body;

public:

    pragma(inline)
    bool bodyIsFinal()
    {
        return state == HTTPParserState.s_message_done;
    }

    ulong httpParserExecute(ubyte[] data)
    {
        handleIng = true;
        scope (exit)
            handleIng = false;
        ubyte c, ch;
        byte unhex_val;
        size_t header_field_mark = uint.max;
        size_t header_value_mark = uint.max;
        size_t url_mark = uint.max;
        size_t body_mark = uint.max;
        size_t status_mark = uint.max;
        size_t maxP = cast(long) data.length;
        size_t p = 0;
        if (http_errno != HTTPParserErrno.HPE_OK)
        {
            return 0;
        }
        if (data.length == 0)
        {
            switch (state)
            {
            case HTTPParserState.s_body_identity_eof:
                /* Use of CALLBACK_NOTIFY() here would erroneously return 1 byte read if
					 * we got paused.
					 */
                mixin(
                    CALLBACK_NOTIFY_NOADVANCE("message_complete"));
                return 0;

            case HTTPParserState.s_dead:
            case HTTPParserState.s_start_req_or_res:
            case HTTPParserState.s_start_res:
            case HTTPParserState.s_start_req:
                return 0;

            default:
                //http_errno = HTTPParserErrno.HPE_INVALID_EOF_STATE);
                http_errno = HTTPParserErrno.HPE_INVALID_EOF_STATE;
                return 1;
            }
        }

        if (state == HTTPParserState.s_header_field)
            header_field_mark = 0;
        if (state == HTTPParserState.s_header_value)
            header_value_mark = 0;
        switch (state)
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
            url_mark = 0;
            break;
        case HTTPParserState.s_res_status:
            status_mark = 0;
            break;
        default:
            break;
        }
        for (; p < maxP; ++p)
        {
            ch = data[p];
            if (state <= HTTPParserState.s_headers_done)
            {
                nread += 1;
                if (nread > _maxHeaderSize)
                {
                    http_errno = HTTPParserErrno.HPE_HEADER_OVERFLOW;
                    goto error;
                }
            }

        reexecute:
            switch (state)
            {
            case HTTPParserState.s_dead:
                /* this state is used after a 'Connection: close' message
					 * the parser will error out if it reads another message
					 */
                if (ch == CR || ch == LF)
                    break;

                http_errno = HTTPParserErrno.HPE_CLOSED_CONNECTION;
                goto error;
            case HTTPParserState.s_start_req_or_res:
                {
                    if (ch == CR || ch == LF)
                        break;
                    flags = HTTPParserFlags.F_ZERO;
                    content_length = ulong.max;

                    if (ch == 'H')
                    {
                        state = HTTPParserState.s_res_or_resp_H;

                        mixin(CALLBACK_NOTIFY("message_begin")); // 开始处理

                    }
                    else
                    {
                        type = HTTPParserType.HTTP_REQUEST;
                        state = HTTPParserState.s_start_req;
                        goto reexecute;
                    }

                    break;
                }
            case HTTPParserState.s_res_or_resp_H:
                if (ch == 'T')
                {
                    type = HTTPParserType.HTTP_RESPONSE;
                    state = HTTPParserState.s_res_HT;
                }
                else
                {
                    if (ch != 'E')
                    {
                        http_errno = HTTPParserErrno.HPE_INVALID_CONSTANT;
                        goto error;
                    }

                    type = HTTPParserType.HTTP_REQUEST;
                    method = HTTPMethod.HTTP_HEAD;
                    index = 2;
                    state = HTTPParserState.s_req_method;
                }
                break;

            case HTTPParserState.s_start_res:
                {
                    flags = HTTPParserFlags.F_ZERO;
                    content_length = ulong.max;

                    switch (ch)
                    {
                    case 'H':
                        state = HTTPParserState.s_res_H;
                        break;

                    case CR:
                    case LF:
                        break;

                    default:
                        http_errno = HTTPParserErrno.HPE_INVALID_CONSTANT;
                        goto error;
                    }
                    mixin(CALLBACK_NOTIFY("message_begin"));
                    break;
                }
            case HTTPParserState.s_res_H:
                mixin(STRICT_CHECK("ch != 'T'"));
                state = HTTPParserState.s_res_HT;
                break;

            case HTTPParserState.s_res_HT:
                //STRICT_CHECK(ch != 'T');
                mixin(STRICT_CHECK("ch != 'T'"));
                state = HTTPParserState.s_res_HTT;
                break;

            case HTTPParserState.s_res_HTT:
                //STRICT_CHECK(ch != 'P');
                mixin(STRICT_CHECK("ch != 'P'"));
                state = HTTPParserState.s_res_HTTP;
                break;

            case HTTPParserState.s_res_HTTP:
                //STRICT_CHECK(ch != '/');
                mixin(STRICT_CHECK("ch != '/'"));
                state = HTTPParserState.s_res_first_http_major;
                break;

            case HTTPParserState.s_res_first_http_major:
                if (ch < '0' || ch > '9')
                {
                    http_errno = HTTPParserErrno.HPE_INVALID_VERSION;
                    goto error;
                }

                http_major = cast(ushort)(ch - '0');
                state = HTTPParserState.s_res_http_major;
                break;

                /* major HTTP version or dot */
            case HTTPParserState.s_res_http_major:
                {
                    if (ch == '.')
                    {
                        state = HTTPParserState.s_res_first_http_minor;
                        break;
                    }

                    if (!mixin(IS_NUM("ch")))
                    {
                        http_errno = HTTPParserErrno.HPE_INVALID_VERSION;
                        goto error;
                    }

                    http_major *= 10;
                    http_major += ch - '0';

                    if (http_major > 999)
                    {
                        http_errno = HTTPParserErrno.HPE_INVALID_VERSION;
                        goto error;
                    }

                    break;
                }

                /* first digit of minor HTTP version */
            case HTTPParserState.s_res_first_http_minor:
                if (!mixin(IS_NUM("ch")))
                {
                    http_errno = HTTPParserErrno.HPE_INVALID_VERSION;
                    goto error;
                }

                http_minor = cast(ushort)(ch - '0');
                state = HTTPParserState.s_res_http_minor;
                break;

                /* minor HTTP version or end of request line */
            case HTTPParserState.s_res_http_minor:
                {
                    if (ch == ' ')
                    {
                        state = HTTPParserState.s_res_first_status_code;
                        break;
                    }

                    if (!mixin(IS_NUM("ch")))
                    {
                        http_errno = HTTPParserErrno.HPE_INVALID_VERSION;
                        goto error;
                    }

                    http_minor *= 10;
                    http_minor += ch - '0';

                    if (http_minor > 999)
                    {
                        http_errno = HTTPParserErrno.HPE_INVALID_VERSION;
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

                        http_errno = HTTPParserErrno.HPE_INVALID_STATUS;
                        goto error;
                    }
                    status_code = ch - '0';
                    state = HTTPParserState.s_res_status_code;
                    break;
                }

            case HTTPParserState.s_res_status_code:
                {
                    if (!mixin(IS_NUM("ch")))
                    {
                        switch (ch)
                        {
                        case ' ':
                            state = HTTPParserState.s_res_status_start;
                            break;
                        case CR:
                            state = HTTPParserState.s_res_line_almost_done;
                            break;
                        case LF:
                            state = HTTPParserState.s_header_field_start;
                            break;
                        default:
                            http_errno = HTTPParserErrno.HPE_INVALID_STATUS;
                            goto error;
                        }
                        break;
                    }

                    status_code *= 10;
                    status_code += ch - '0';

                    if (status_code > 999)
                    {
                        http_errno = HTTPParserErrno.HPE_INVALID_STATUS;
                        goto error;
                    }

                    break;
                }

            case HTTPParserState.s_res_status_start:
                {
                    if (ch == CR)
                    {
                        state = HTTPParserState.s_res_line_almost_done;
                        break;
                    }

                    if (ch == LF)
                    {
                        state = HTTPParserState.s_header_field_start;
                        break;
                    }

                    //MARK(status);
                    if (status_mark == uint.max)
                    {
                        status_mark = p;
                    }
                    state = HTTPParserState.s_res_status;
                    index = 0;
                    break;
                }

            case HTTPParserState.s_res_status:
                if (ch == CR)
                {
                    state = HTTPParserState.s_res_line_almost_done;
                    mixin(CALLBACK_DATA("status"));
                    break;
                }

                if (ch == LF)
                {
                    state = HTTPParserState.s_header_field_start;
                    //statusCall();
                    mixin(CALLBACK_DATA("status"));
                    break;
                }

                break;

            case HTTPParserState.s_res_line_almost_done:
                mixin(STRICT_CHECK("ch != LF"));
                state = HTTPParserState.s_header_field_start;
                break;

            case HTTPParserState.s_start_req:
                {
                    if (ch == CR || ch == LF)
                        break;
                    flags = HTTPParserFlags.F_ZERO;
                    content_length = ulong.max;

                    if (!mixin(IS_ALPHA("ch")))
                    {
                        //error("err0");
                        http_errno = HTTPParserErrno.HPE_INVALID_METHOD;
                        goto error;
                    }

                    index = 1;
                    switch (ch)
                    {
                    case 'A':
                        method = HTTPMethod.HTTP_ACL;
                        break;
                    case 'B':
                        method = HTTPMethod.HTTP_BIND;
                        break;
                    case 'C':
                        method = HTTPMethod.HTTP_CONNECT; /* or COPY, CHECKOUT */ break;
                    case 'D':
                        method = HTTPMethod.HTTP_DELETE;
                        break;
                    case 'G':
                        method = HTTPMethod.HTTP_GET;
                        break;
                    case 'H':
                        method = HTTPMethod.HTTP_HEAD;
                        break;
                    case 'L':
                        method = HTTPMethod.HTTP_LOCK; /* or LINK */ break;
                    case 'M':
                        method = HTTPMethod.HTTP_MKCOL; /* or MOVE, MKACTIVITY, MERGE, M-SEARCH, MKCALENDAR */ break;
                    case 'N':
                        method = HTTPMethod.HTTP_NOTIFY;
                        break;
                    case 'O':
                        method = HTTPMethod.HTTP_OPTIONS;
                        break;
                    case 'P':
                        method = HTTPMethod.HTTP_POST;
                        /* or PROPFIND|PROPPATCH|PUT|PATCH|PURGE */
                        break;
                    case 'R':
                        method = HTTPMethod.HTTP_REPORT; /* or REBIND */ break;
                    case 'S':
                        method = HTTPMethod.HTTP_SUBSCRIBE; /* or SEARCH */ break;
                    case 'T':
                        method = HTTPMethod.HTTP_TRACE;
                        break;
                    case 'U':
                        method = HTTPMethod.HTTP_UNLOCK; /* or UNSUBSCRIBE, UNBIND, UNLINK */ break;
                    default:
                        //error("err0");
                        http_errno = HTTPParserErrno.HPE_INVALID_METHOD;
                        goto error;
                    }
                    state = HTTPParserState.s_req_method;

                    mixin(CALLBACK_NOTIFY("message_begin"));
                    break;
                }

            case HTTPParserState.s_req_method:
                {
                    if (ch == '\0')
                    {
                        //error("err0");
                        http_errno = HTTPParserErrno.HPE_INVALID_METHOD;
                        goto error;
                    }

                    string matcher = method_strings[method];
                    if (ch == ' ' && matcher.length == index)
                    {
                        state = HTTPParserState.s_req_spaces_before_url;
                    }
                    else if (ch == matcher[index])
                    {
                        //; /* nada */
                    }
                    else if (method == HTTPMethod.HTTP_CONNECT)
                    {
                        if (index == 1 && ch == 'H')
                        {
                            method = HTTPMethod.HTTP_CHECKOUT;
                        }
                        else if (index == 2 && ch == 'P')
                        {
                            method = HTTPMethod.HTTP_COPY;
                        }
                        else
                        {
                            //error("err0");
                            http_errno = HTTPParserErrno.HPE_INVALID_METHOD;
                            goto error;
                        }
                    }
                    else if (method == HTTPMethod.HTTP_MKCOL)
                    {
                        if (index == 1 && ch == 'O')
                        {
                            method = HTTPMethod.HTTP_MOVE;
                        }
                        else if (index == 1 && ch == 'E')
                        {
                            method = HTTPMethod.HTTP_MERGE;
                        }
                        else if (index == 1 && ch == '-')
                        {
                            method = HTTPMethod.HTTP_MSEARCH;
                        }
                        else if (index == 2 && ch == 'A')
                        {
                            method = HTTPMethod.HTTP_MKACTIVITY;
                        }
                        else if (index == 3 && ch == 'A')
                        {
                            method = HTTPMethod.HTTP_MKCALENDAR;
                        }
                        else
                        {
                            //error("err0");
                            http_errno = HTTPParserErrno.HPE_INVALID_METHOD;
                            goto error;
                        }
                    }
                    else if (method == HTTPMethod.HTTP_SUBSCRIBE)
                    {
                        if (index == 1 && ch == 'E')
                        {
                            method = HTTPMethod.HTTP_SEARCH;
                        }
                        else
                        {
                            //error("err0");
                            http_errno = HTTPParserErrno.HPE_INVALID_METHOD;
                            goto error;
                        }
                    }
                    else if (method == HTTPMethod.HTTP_REPORT)
                    {
                        if (index == 2 && ch == 'B')
                        {
                            //error("err0");
                            method = HTTPMethod.HTTP_REBIND;
                        }
                        else
                        {
                            http_errno = HTTPParserErrno.HPE_INVALID_METHOD;
                            goto error;
                        }
                    }
                    else if (index == 1)
                    {
                        if (method == HTTPMethod.HTTP_POST)
                        {

                            if (ch == 'R')
                            {
                                method = HTTPMethod.HTTP_PROPFIND; /* or HTTP_PROPPATCH */
                            }
                            else if (ch == 'U')
                            {
                                method = HTTPMethod.HTTP_PUT; /* or HTTP_PURGE */
                            }
                            else if (ch == 'A')
                            {
                                method = HTTPMethod.HTTP_PATCH;
                            }
                            else
                            {
                                //error("err0");
                                http_errno = HTTPParserErrno.HPE_INVALID_METHOD;
                                goto error;
                            }
                        }
                        else if (method == HTTPMethod.HTTP_LOCK)
                        {
                            if (ch == 'I')
                            {
                                method = HTTPMethod.HTTP_LINK;
                            }
                            else
                            {
                                //error("err0");
                                http_errno = HTTPParserErrno.HPE_INVALID_METHOD;
                                goto error;
                            }
                        }
                    }
                    else if (index == 2)
                    {
                        if (method == HTTPMethod.HTTP_PUT)
                        {
                            if (ch == 'R')
                            {
                                method = HTTPMethod.HTTP_PURGE;
                            }
                            else
                            {
                                //error("err0");
                                http_errno = HTTPParserErrno.HPE_INVALID_METHOD;
                                goto error;
                            }
                        }
                        else if (method == HTTPMethod.HTTP_UNLOCK)
                        {
                            if (ch == 'S')
                            {
                                method = HTTPMethod.HTTP_UNSUBSCRIBE;
                            }
                            else if (ch == 'B')
                            {
                                method = HTTPMethod.HTTP_UNBIND;
                            }
                            else
                            {
                                //error("err0");
                                http_errno = HTTPParserErrno.HPE_INVALID_METHOD;
                                goto error;
                            }
                        }
                        else
                        {
                            //error("err0");
                            http_errno = HTTPParserErrno.HPE_INVALID_METHOD;
                            goto error;
                        }
                    }
                    else if (index == 4 && method == HTTPMethod.HTTP_PROPFIND && ch == 'P')
                    {
                        method = HTTPMethod.HTTP_PROPPATCH;
                    }
                    else if (index == 3 && method == HTTPMethod.HTTP_UNLOCK && ch == 'I')
                    {
                        method = HTTPMethod.HTTP_UNLINK;
                    }
                    else
                    {
                        //error("err0");
                        http_errno = HTTPParserErrno.HPE_INVALID_METHOD;
                        goto error;
                    }

                    ++index;
                    break;
                }

            case HTTPParserState.s_req_spaces_before_url:
                {
                    if (ch == ' ')
                        break;

                    //MARK(url);
                    if (url_mark == uint.max)
                    {
                        url_mark = p;
                    }
                    if (method == HTTPMethod.HTTP_CONNECT)
                    {
                        state = HTTPParserState.s_req_server_start;
                    }

                    state = parseURLchar(state, ch);
                    if (state == HTTPParserState.s_dead)
                    {
                        http_errno = HTTPParserErrno.HPE_INVALID_URL;
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
                        http_errno = HTTPParserErrno.HPE_INVALID_URL;
                        goto error;
                    default:
                        state = parseURLchar(state, ch);
                        if (state == HTTPParserState.s_dead)
                        {
                            http_errno = HTTPParserErrno.HPE_INVALID_URL;
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
                        state = HTTPParserState.s_req_http_start;
                        mixin(CALLBACK_DATA("url"));
                        break;
                    case CR:
                    case LF:
                        http_major = 0;
                        http_minor = 9;
                        state = (ch == CR) ? HTTPParserState.s_req_line_almost_done
                            : HTTPParserState.s_header_field_start;
                        mixin(CALLBACK_DATA("url"));
                        break;
                    default:
                        state = parseURLchar(state, ch);
                        if (state == HTTPParserState.s_dead)
                        {
                            http_errno = HTTPParserErrno.HPE_INVALID_URL;
                            goto error;
                        }
                    }
                    break;
                }

            case HTTPParserState.s_req_http_start:
                switch (ch)
                {
                case 'H':
                    state = HTTPParserState.s_req_http_H;
                    break;
                case ' ':
                    break;
                default:
                    http_errno = HTTPParserErrno.HPE_INVALID_CONSTANT;
                    goto error;
                }
                break;

            case HTTPParserState.s_req_http_H:
                mixin(STRICT_CHECK("ch != 'T'"));
                state = HTTPParserState.s_req_http_HT;
                break;

            case HTTPParserState.s_req_http_HT:
                //STRICT_CHECK(ch != 'T');
                mixin(STRICT_CHECK("ch != 'T'"));
                state = HTTPParserState.s_req_http_HTT;
                break;

            case HTTPParserState.s_req_http_HTT:
                //STRICT_CHECK(ch != 'P');
                mixin(STRICT_CHECK("ch != 'P'"));
                state = HTTPParserState.s_req_http_HTTP;
                break;

            case HTTPParserState.s_req_http_HTTP:
                //STRICT_CHECK(ch != '/');
                mixin(STRICT_CHECK("ch != '/'"));
                state = HTTPParserState.s_req_first_http_major;
                break;

                /* first digit of major HTTP version */
            case HTTPParserState.s_req_first_http_major:
                if (ch < '1' || ch > '9')
                {
                    http_errno = HTTPParserErrno.HPE_INVALID_VERSION;
                    goto error;
                }

                http_major = cast(ushort)(ch - '0');
                state = HTTPParserState.s_req_http_major;
                break;

                /* major HTTP version or dot */
            case HTTPParserState.s_req_http_major:
                {
                    if (ch == '.')
                    {
                        state = HTTPParserState.s_req_first_http_minor;
                        break;
                    }

                    if (!mixin(IS_NUM("ch")))
                    {
                        http_errno = HTTPParserErrno.HPE_INVALID_VERSION;
                        goto error;
                    }

                    http_major *= 10;
                    http_major += ch - '0';

                    if (http_major > 999)
                    {
                        http_errno = HTTPParserErrno.HPE_INVALID_VERSION;
                        goto error;
                    }

                    break;
                }

                /* first digit of minor HTTP version */
            case HTTPParserState.s_req_first_http_minor:
                if (!mixin(IS_NUM("ch")))
                {
                    http_errno = HTTPParserErrno.HPE_INVALID_VERSION;
                    goto error;
                }

                http_minor = cast(ushort)(ch - '0');
                state = HTTPParserState.s_req_http_minor;
                break;

                /* minor HTTP version or end of request line */
            case HTTPParserState.s_req_http_minor:
                {
                    if (ch == CR)
                    {
                        state = HTTPParserState.s_req_line_almost_done;
                        break;
                    }

                    if (ch == LF)
                    {
                        state = HTTPParserState.s_header_field_start;
                        break;
                    }

                    /* XXX allow spaces after digit? */

                    if (!mixin(IS_NUM("ch")))
                    {
                        http_errno = HTTPParserErrno.HPE_INVALID_VERSION;
                        goto error;
                    }

                    http_minor *= 10;
                    http_minor += ch - '0';

                    if (http_minor > 999)
                    {
                        http_errno = HTTPParserErrno.HPE_INVALID_VERSION;
                        goto error;
                    }

                    break;
                }

                /* end of request line */
            case HTTPParserState.s_req_line_almost_done:
                {
                    if (ch != LF)
                    {
                        http_errno = HTTPParserErrno.HPE_LF_EXPECTED;
                        goto error;
                    }

                    state = HTTPParserState.s_header_field_start;
                    break;
                }

            case HTTPParserState.s_header_field_start:
                {
                    if (ch == CR)
                    {
                        state = HTTPParserState.s_headers_almost_done;
                        break;
                    }

                    if (ch == LF)
                    {
                        /* they might be just sending \n instead of \r\n so this would be
						 * the second \n to denote the end of headers*/
                        state = HTTPParserState.s_headers_almost_done;
                        //goto reexecute;
                        goto reexecute;
                    }

                    c = tokens[ch];

                    if (!c)
                    {
                        http_errno = HTTPParserErrno.HPE_INVALID_HEADER_TOKEN;
                        goto error;
                    }

                    if (header_field_mark == uint.max)
                    {
                        header_field_mark = p;
                    }

                    index = 0;
                    state = HTTPParserState.s_header_field;

                    switch (c)
                    {
                    case 'c':
                        header_state = HTTPParserHeaderstates.h_C;
                        break;

                    case 'p':
                        header_state = HTTPParserHeaderstates.h_matching_proxy_connection;
                        break;

                    case 't':
                        header_state = HTTPParserHeaderstates.h_matching_transfer_encoding;
                        break;

                    case 'u':
                        header_state = HTTPParserHeaderstates.h_matching_upgrade;
                        break;

                    default:
                        header_state = HTTPParserHeaderstates.h_general;
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

                        switch (header_state)
                        {
                        case HTTPParserHeaderstates.h_general:
                            break;

                        case HTTPParserHeaderstates.h_C:
                            index++;
                            header_state = (
                                c == 'o' ? HTTPParserHeaderstates.h_CO
                                : HTTPParserHeaderstates.h_general);
                            break;

                        case HTTPParserHeaderstates.h_CO:
                            index++;
                            header_state = (
                                c == 'n' ? HTTPParserHeaderstates.h_CON
                                : HTTPParserHeaderstates.h_general);
                            break;

                        case HTTPParserHeaderstates.h_CON:
                            index++;
                            switch (c)
                            {
                            case 'n':
                                header_state = HTTPParserHeaderstates.h_matching_connection;
                                break;
                            case 't':
                                header_state = HTTPParserHeaderstates.h_matching_content_length;
                                break;
                            default:
                                header_state = HTTPParserHeaderstates.h_general;
                                break;
                            }
                            break;

                            /* connection */

                        case HTTPParserHeaderstates.h_matching_connection:
                            index++;
                            if (index > CONNECTION.length || c != CONNECTION[index])
                            {
                                header_state = HTTPParserHeaderstates.h_general;
                            }
                            else if (index == CONNECTION.length - 1)
                            {
                                header_state = HTTPParserHeaderstates.h_connection;
                            }
                            break;

                            /* proxy-connection */

                        case HTTPParserHeaderstates.h_matching_proxy_connection:
                            index++;
                            if (index > PROXY_CONNECTION.length || c != PROXY_CONNECTION[index])
                            {
                                header_state = HTTPParserHeaderstates.h_general;
                            }
                            else if (index == PROXY_CONNECTION.length)
                            {
                                header_state = HTTPParserHeaderstates.h_connection;
                            }
                            break;

                            /* content-length */

                        case HTTPParserHeaderstates.h_matching_content_length:
                            index++;
                            if (index > CONTENT_LENGTH.length || c != CONTENT_LENGTH[index])
                            {
                                header_state = HTTPParserHeaderstates.h_general;
                            }
                            else if (index == CONTENT_LENGTH.length - 1)
                            {
                                if (flags & HTTPParserFlags.F_CONTENTLENGTH)
                                {
                                    http_errno = HTTPParserErrno.HPE_UNEXPECTED_CONTENT_LENGTH;
                                    goto error;
                                }
                                header_state = HTTPParserHeaderstates.h_content_length;
                                flags |= HTTPParserFlags.F_CONTENTLENGTH;
                            }
                            break;

                            /* transfer-encoding */

                        case HTTPParserHeaderstates.h_matching_transfer_encoding:
                            index++;
                            if (index > TRANSFER_ENCODING.length || c != TRANSFER_ENCODING[index])
                            {
                                header_state = HTTPParserHeaderstates.h_general;
                            }
                            else if (index == TRANSFER_ENCODING.length - 1)
                            {
                                header_state = HTTPParserHeaderstates.h_transfer_encoding;
                            }
                            break;

                            /* upgrade */

                        case HTTPParserHeaderstates.h_matching_upgrade:
                            index++;
                            if (index > UPGRADE.length || c != UPGRADE[index])
                            {
                                header_state = HTTPParserHeaderstates.h_general;
                            }
                            else if (index == UPGRADE.length - 1)
                            {
                                header_state = HTTPParserHeaderstates.h_upgrade;
                            }
                            break;

                        case HTTPParserHeaderstates.h_connection:
                        case HTTPParserHeaderstates.h_content_length:
                        case HTTPParserHeaderstates.h_transfer_encoding:
                        case HTTPParserHeaderstates.h_upgrade:
                            if (
                                    ch != ' ')
                                header_state = HTTPParserHeaderstates.h_general;
                            break;

                        default:
                            assert(false, "Unknown header_state");
                            //	break;
                        }
                    }

                    //COUNT_HEADER_SIZE(p - start);
                    nread += (p - start);
                    if (nread > _maxHeaderSize)
                    {
                        http_errno = HTTPParserErrno.HPE_HEADER_OVERFLOW;
                        goto error;
                    }

                    if (p == maxP)
                    {
                        --p;
                        break;
                    }

                    if (ch == ':')
                    {
                        state = HTTPParserState.s_header_value_discard_ws;
                        mixin(CALLBACK_DATA("header_field"));
                        break;
                    }

                    http_errno = HTTPParserErrno.HPE_INVALID_HEADER_TOKEN;
                    goto error;
                }

            case HTTPParserState.s_header_value_discard_ws:
                if (ch == ' ' || ch == '\t')
                    break;

                if (ch == CR)
                {
                    state = HTTPParserState.s_header_value_discard_ws_almost_done;
                    break;
                }

                if (ch == LF)
                {
                    state = HTTPParserState.s_header_value_discard_lws;
                    break;
                }
                goto case;
                /* FALLTHROUGH */

            case HTTPParserState.s_header_value_start:
                {
                    //MARK(header_value);
                    if (header_value_mark == uint.max)
                    {
                        header_value_mark = p;
                    }
                    state = HTTPParserState.s_header_value;
                    index = 0;

                    c = ch | 0x20; //LOWER(ch);

                    switch (header_state)
                    {
                    case HTTPParserHeaderstates.h_upgrade:
                        flags |= HTTPParserFlags.F_UPGRADE;
                        header_state = HTTPParserHeaderstates.h_general;
                        break;

                    case HTTPParserHeaderstates.h_transfer_encoding:
                        /* looking for 'Transfer-Encoding: chunked' */
                        if ('c' == c)
                        {
                            header_state = HTTPParserHeaderstates
                                .h_matching_transfer_encoding_chunked;
                        }
                        else
                        {
                            header_state = HTTPParserHeaderstates.h_general;
                        }
                        break;

                    case HTTPParserHeaderstates.h_content_length:
                        if (!mixin(IS_NUM("ch")))
                        {
                            http_errno = HTTPParserErrno.HPE_INVALID_CONTENT_LENGTH;
                            goto error;
                        }

                        content_length = ch - '0';
                        break;

                    case HTTPParserHeaderstates.h_connection:
                        /* looking for 'Connection: keep-alive' */
                        if (c == 'k')
                        {
                            header_state = HTTPParserHeaderstates.h_matching_connection_keep_alive;
                            /* looking for 'Connection: close' */
                        }
                        else if (c == 'c')
                        {
                            header_state = HTTPParserHeaderstates.h_matching_connection_close;
                        }
                        else if (c == 'u')
                        {
                            header_state = HTTPParserHeaderstates.h_matching_connection_upgrade;
                        }
                        else
                        {
                            header_state = HTTPParserHeaderstates.h_matching_connection_token;
                        }
                        break;

                        /* Multi-value `Connection` header */
                    case HTTPParserHeaderstates.h_matching_connection_token_start:
                        break;

                    default:
                        header_state = HTTPParserHeaderstates.h_general;
                        break;
                    }
                    break;
                }

            case HTTPParserState.s_header_value: //BUG，找不到结束
            {
                    const long start = p;
                    auto h_state = header_state;
                    for (; p < maxP; p++)
                    {
                        ch = data[p];
                        if (ch == CR)
                        {
                            state = HTTPParserState.s_header_almost_done;
                            header_state = h_state;
                            mixin(CALLBACK_DATA("header_value"));
                            break;
                        }

                        if (ch == LF)
                        {
                            state = HTTPParserState.s_header_almost_done;
                            //COUNT_HEADER_SIZE(p - start);
                            nread += (p - start);
                            if (nread > _maxHeaderSize)
                            {
                                http_errno = HTTPParserErrno.HPE_HEADER_OVERFLOW;
                                goto error;
                            }
                            header_state = h_state;
                            mixin(CALLBACK_DATA_NOADVANCE("header_value"));
                            goto reexecute;
                        }

                        if (!lenient_http_headers && !(ch == CR || ch == LF
                                || ch == 9 || (ch > 31 && ch != 127)))
                        {
                            http_errno = HTTPParserErrno.HPE_INVALID_HEADER_TOKEN;
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
                                string str = cast(string) data[p .. maxP];
                                auto p_cr = str.indexOf(CR); // memchr(p, CR, limit);
                                auto p_lf = str.indexOf(LF); // memchr(p, LF, limit);
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
                                    http_errno = HTTPParserErrno.HPE_INVALID_CONTENT_LENGTH;
                                    header_state = h_state;
                                    goto error;
                                }

                                t = content_length;
                                t *= 10;
                                t += ch - '0';

                                /* Overflow? Test against a conservative limit for simplicity. */
                                if ((ulong.max - 10) / 10 < content_length)
                                {
                                    http_errno = HTTPParserErrno.HPE_INVALID_CONTENT_LENGTH;
                                    header_state = h_state;
                                    goto error;
                                }

                                content_length = t;
                                break;
                            }

                            /* Transfer-Encoding: chunked */
                        case HTTPParserHeaderstates.h_matching_transfer_encoding_chunked:
                            index++;
                            if (index > CHUNKED.length || c != CHUNKED[index])
                            {
                                h_state = HTTPParserHeaderstates.h_general;
                            }
                            else if (index == CHUNKED.length - 1)
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
                            index++;
                            if (index > KEEP_ALIVE.length || c != KEEP_ALIVE[index])
                            {
                                h_state = HTTPParserHeaderstates.h_matching_connection_token;
                            }
                            else if (index == KEEP_ALIVE.length - 1)
                            {
                                h_state = HTTPParserHeaderstates.h_connection_keep_alive;
                            }
                            break;

                            /* looking for 'Connection: close' */
                        case HTTPParserHeaderstates.h_matching_connection_close:
                            index++;
                            if (index > CLOSE.length || c != CLOSE[index])
                            {
                                h_state = HTTPParserHeaderstates.h_matching_connection_token;
                            }
                            else if (index == CLOSE.length - 1)
                            {
                                h_state = HTTPParserHeaderstates.h_connection_close;
                            }
                            break;

                            /* looking for 'Connection: upgrade' */
                        case HTTPParserHeaderstates.h_matching_connection_upgrade:
                            index++;
                            if (index > UPGRADE.length || c != UPGRADE[index])
                            {
                                h_state = HTTPParserHeaderstates.h_matching_connection_token;
                            }
                            else if (index == UPGRADE.length - 1)
                            {
                                h_state = HTTPParserHeaderstates.h_connection_upgrade;
                            }
                            break;

                        case HTTPParserHeaderstates.h_matching_connection_token:
                            if (ch == ',')
                            {
                                h_state = HTTPParserHeaderstates.h_matching_connection_token_start;
                                index = 0;
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
                                    flags |= HTTPParserFlags.F_CONNECTION_KEEP_ALIVE;
                                }
                                else if (h_state == HTTPParserHeaderstates.h_connection_close)
                                {
                                    flags |= HTTPParserFlags.F_CONNECTION_CLOSE;
                                }
                                else if (h_state == HTTPParserHeaderstates.h_connection_upgrade)
                                {
                                    flags |= HTTPParserFlags.F_CONNECTION_UPGRADE;
                                }
                                h_state = HTTPParserHeaderstates.h_matching_connection_token_start;
                                index = 0;
                            }
                            else if (ch != ' ')
                            {
                                h_state = HTTPParserHeaderstates.h_matching_connection_token;
                            }
                            break;

                        default:
                            state = HTTPParserState.s_header_value;
                            h_state = HTTPParserHeaderstates.h_general;
                            break;
                        }
                    }

                    header_state = h_state;

                    //COUNT_HEADER_SIZE(p - start);
                    nread += (p - start);
                    if (nread > _maxHeaderSize)
                    {
                        http_errno = HTTPParserErrno.HPE_HEADER_OVERFLOW;
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
                        http_errno = HTTPParserErrno.HPE_LF_EXPECTED;
                        goto error;
                    }

                    state = HTTPParserState.s_header_value_lws;
                    break;
                }

            case HTTPParserState.s_header_value_lws:
                {
                    if (ch == ' ' || ch == '\t')
                    {
                        state = HTTPParserState.s_header_value_start;
                        goto reexecute;
                    }

                    /* finished the header */
                    switch (header_state)
                    {
                    case HTTPParserHeaderstates.h_connection_keep_alive:
                        flags |= HTTPParserFlags.F_CONNECTION_KEEP_ALIVE;
                        break;
                    case HTTPParserHeaderstates.h_connection_close:
                        flags
                            |= HTTPParserFlags.F_CONNECTION_CLOSE;
                        break;
                    case HTTPParserHeaderstates.h_transfer_encoding_chunked:
                        flags |= HTTPParserFlags.F_CHUNKED;
                        break;
                    case HTTPParserHeaderstates.h_connection_upgrade:
                        flags
                            |= HTTPParserFlags.F_CONNECTION_UPGRADE;
                        break;
                    default:
                        break;
                    }

                    state = HTTPParserState.s_header_field_start;
                    goto reexecute;
                }

            case HTTPParserState.s_header_value_discard_ws_almost_done:
                {
                    mixin(STRICT_CHECK("ch != LF"));
                    state = HTTPParserState.s_header_value_discard_lws;
                    break;
                }

            case HTTPParserState.s_header_value_discard_lws:
                {
                    if (ch == ' ' || ch == '\t')
                    {
                        state = HTTPParserState.s_header_value_discard_ws;
                        break;
                    }
                    else
                    {
                        switch (header_state)
                        {
                        case HTTPParserHeaderstates.h_connection_keep_alive:
                            flags |= HTTPParserFlags.F_CONNECTION_KEEP_ALIVE;
                            break;
                        case HTTPParserHeaderstates.h_connection_close:
                            flags
                                |= HTTPParserFlags.F_CONNECTION_CLOSE;
                            break;
                        case HTTPParserHeaderstates.h_connection_upgrade:
                            flags |= HTTPParserFlags.F_CONNECTION_UPGRADE;
                            break;
                        case HTTPParserHeaderstates.h_transfer_encoding_chunked:
                            flags |= HTTPParserFlags.F_CHUNKED;
                            break;
                        default:
                            break;
                        }

                        /* header value was empty */
                        //MARK(header_value);
                        if (header_value_mark == uint.max)
                        {
                            header_value_mark = p;
                        }
                        state = HTTPParserState.s_header_field_start;
                        mixin(CALLBACK_DATA_NOADVANCE("header_value"));
                        goto reexecute;
                    }
                }
                //TODO	
            case HTTPParserState.s_headers_almost_done:
                {
                    mixin(STRICT_CHECK("ch != LF"));

                    if (flags & HTTPParserFlags.F_TRAILING)
                    {
                        /* End of a chunked request */
                        state = HTTPParserState.s_message_done;
                        mixin(CALLBACK_NOTIFY_NOADVANCE("chunk_complete"));
                        goto reexecute;
                    }

                    /* Cannot use chunked encoding and a content-length header together
					 per the HTTP specification. */
                    if ((flags & HTTPParserFlags.F_CHUNKED)
                            && (flags & HTTPParserFlags.F_CONTENTLENGTH))
                    {
                        http_errno = HTTPParserErrno.HPE_UNEXPECTED_CONTENT_LENGTH;
                        goto error;
                    }

                    state = HTTPParserState.s_headers_done;

                    /* Set this here so that on_headers_complete() callbacks can see it */
                    upgrade = (
                        (flags & (HTTPParserFlags.F_UPGRADE | HTTPParserFlags.F_CONNECTION_UPGRADE)) == (
                        HTTPParserFlags.F_UPGRADE | HTTPParserFlags.F_CONNECTION_UPGRADE)
                        || method == HTTPMethod.HTTP_CONNECT);
                    {
                        if (_on_headers_complete != null)
                        {
                            _on_headers_complete(this);
                            //error("_on_headers_complete " , errorString);
                            //error("handleIng  " , handleIng);
                            //error("handleIng  " , skipBody);
                            //error("state  " , state);
                            if (!handleIng)
                            {
                                http_errno = HTTPParserErrno.HPE_CB_headers_complete;
                                return p; /* Error */
                            }
                            if (skipBody)
                                flags |= HTTPParserFlags.F_SKIPBODY;

                        }

                    }

                    goto reexecute;
                }

            case HTTPParserState.s_headers_done:
                {
                    int hasBody;
                    mixin(STRICT_CHECK("ch != LF"));

                    nread = 0;
                    //int chunked = flags & HTTPParserFlags.F_CHUNKED ;
                    //error("s_headers_done is chunked : ", chunked);
                    hasBody = flags & HTTPParserFlags.F_CHUNKED
                        || (content_length > 0 && content_length != ULLONG_MAX);
                    if (upgrade && (method == HTTPMethod.HTTP_CONNECT
                            || (flags & HTTPParserFlags.F_SKIPBODY) || !hasBody))
                    {
                        /* Exit, the rest of the message is in a different protocol. */
                        state = mixin(NEW_MESSAGE);
                        mixin(CALLBACK_NOTIFY("message_complete"));
                        return (p + 1);
                    }

                    if (flags & HTTPParserFlags.F_SKIPBODY)
                    {
                        state = mixin(NEW_MESSAGE);
                        mixin(CALLBACK_NOTIFY("message_complete"));
                    }
                    else if (flags & HTTPParserFlags.F_CHUNKED)
                    {
                        /* chunked encoding - ignore Content-Length header */
                        state = HTTPParserState.s_chunk_size_start;
                    }
                    else
                    {
                        if (content_length == 0)
                        {
                            /* Content-Length header given but zero: Content-Length: 0\r\n */
                            state = mixin(NEW_MESSAGE);
                            mixin(CALLBACK_NOTIFY("message_complete"));
                        }
                        else if (content_length != ULLONG_MAX)
                        {
                            /* Content-Length header given and non-zero */
                            state = HTTPParserState.s_body_identity;
                        }
                        else
                        {
                            if (!httpMessageNeedsEof())
                            {
                                /* Assume content-length 0 - read the next */
                                state = mixin(NEW_MESSAGE);
                                mixin(CALLBACK_NOTIFY("message_complete"));
                            }
                            else
                            {
                                /* Read body until EOF */
                                state = HTTPParserState.s_body_identity_eof;
                            }
                        }
                    }

                    break;
                }

            case HTTPParserState.s_body_identity:
                {
                    ulong to_read = content_length < cast(ulong)(maxP - p) ? content_length : cast(
                        ulong)(maxP - p);

                    assert(content_length != 0 && content_length != ULLONG_MAX);

                    /* The difference between advancing content_length and p is because
					 * the latter will automaticaly advance on the next loop iteration.
					 * Further, if content_length ends up at 0, we want to see the last
					 * byte again for our message complete callback.
					 */
                    //MARK(body);

                    if (body_mark == uint.max)
                    {
                        body_mark = p;
                    }
                    content_length -= to_read;
                    p += to_read - 1;

                    if (content_length == 0)
                    {
                        state = HTTPParserState.s_message_done;

                        /* Mimic CALLBACK_DATA_NOADVANCE() but with one extra byte.
						 *
						 * The alternative to doing this is to wait for the next byte to
						 * trigger the data callback, just as in every other case. The
						 * problem with this is that this makes it difficult for the test
						 * harness to distinguish between complete-on-EOF and
						 * complete-on-length. It's not clear that this distinction is
						 * important for applications, but let's keep it for now.
						 */
                        if (body_mark != uint.max && _on_body != null)
                        {
                            ubyte[] _data = data[body_mark .. p + 1];
                            _on_body(this, _data, true);
                            if (!handleIng)
                            {
                                http_errno = HTTPParserErrno.HPE_CB_body;
                                return p + 1;
                            }
                        }
                        body_mark = uint.max;
                        goto reexecute;
                    }

                    break;
                }

                /* read until EOF */
            case HTTPParserState.s_body_identity_eof:
                //MARK(body);
                if (body_mark == uint.max)
                {
                    body_mark = p;
                }

                p = maxP - 1;

                break;

            case HTTPParserState.s_message_done:
                state = mixin(NEW_MESSAGE);
                mixin(CALLBACK_NOTIFY("message_complete"));
                if (upgrade)
                {
                    /* Exit, the rest of the message is in a different protocol. */
                    return (p + 1);
                }
                break;

            case HTTPParserState.s_chunk_size_start:
                {
                    assert(nread == 1);
                    assert(flags & HTTPParserFlags.F_CHUNKED);

                    unhex_val = unhex[ch];
                    if (unhex_val == -1)
                    {
                        http_errno = HTTPParserErrno.HPE_INVALID_CHUNK_SIZE;
                        goto error;
                    }

                    content_length = unhex_val;
                    state = HTTPParserState.s_chunk_size;
                    break;
                }

            case HTTPParserState.s_chunk_size:
                {
                    ulong t;

                    assert(flags & HTTPParserFlags.F_CHUNKED);

                    if (ch == CR)
                    {
                        state = HTTPParserState.s_chunk_size_almost_done;
                        break;
                    }

                    unhex_val = unhex[ch];

                    if (unhex_val == -1)
                    {
                        if (ch == ';' || ch == ' ')
                        {
                            state = HTTPParserState.s_chunk_parameters;
                            break;
                        }

                        http_errno = HTTPParserErrno.HPE_INVALID_CHUNK_SIZE;
                        goto error;
                    }

                    t = content_length;
                    t *= 16;
                    t += unhex_val;

                    /* Overflow? Test against a conservative limit for simplicity. */
                    if ((ULLONG_MAX - 16) / 16 < content_length)
                    {
                        http_errno = HTTPParserErrno.HPE_INVALID_CONTENT_LENGTH;
                        goto error;
                    }

                    content_length = t;
                    break;
                }

            case HTTPParserState.s_chunk_parameters:
                {
                    assert(flags & HTTPParserFlags.F_CHUNKED);
                    /* just ignore this shit. TODO check for overflow */
                    if (ch == CR)
                    {
                        state = HTTPParserState.s_chunk_size_almost_done;
                        break;
                    }
                    break;
                }

            case HTTPParserState.s_chunk_size_almost_done:
                {
                    assert(flags & HTTPParserFlags.F_CHUNKED);
                    mixin(STRICT_CHECK("ch != LF"));

                    nread = 0;

                    if (content_length == 0)
                    {
                        flags |= HTTPParserFlags.F_TRAILING;
                        state = HTTPParserState.s_header_field_start;
                    }
                    else
                    {
                        state = HTTPParserState.s_chunk_data;
                    }
                    mixin(CALLBACK_NOTIFY("chunk_header"));
                    break;
                }

            case HTTPParserState.s_chunk_data:
                {
                    ulong to_read = content_length < cast(ulong)(maxP - p) ? content_length : cast(
                        ulong)(maxP - p);

                    assert(flags & HTTPParserFlags.F_CHUNKED);
                    assert(content_length != 0 && content_length != ULLONG_MAX);

                    /* See the explanation in s_body_identity for why the content
					 * length and data pointers are managed this way.
					 */
                    //MARK(body);
                    if (body_mark == uint.max)
                    {
                        body_mark = p;
                    }
                    content_length -= to_read;
                    p += to_read - 1;

                    if (content_length == 0)
                    {
                        state = HTTPParserState.s_chunk_data_almost_done;
                    }

                    break;
                }

            case HTTPParserState.s_chunk_data_almost_done:
                assert(flags & HTTPParserFlags.F_CHUNKED);
                assert(content_length == 0);
                mixin(STRICT_CHECK("ch != CR"));
                state = HTTPParserState.s_chunk_data_done;
                mixin(CALLBACK_DATA("body"));
                break;

            case HTTPParserState.s_chunk_data_done:
                assert(flags & HTTPParserFlags.F_CHUNKED);
                mixin(STRICT_CHECK("ch != LF"));
                nread = 0;
                state = HTTPParserState.s_chunk_size_start;
                mixin(CALLBACK_NOTIFY("chunk_complete"));
                break;

            default:
                //assert(0 && "unhandled state");
                http_errno = HTTPParserErrno.HPE_INVALID_INTERNAL_STATE;
                goto error;
            }
        }

        assert(
            (
            (header_field_mark != uint.max ? 1 : 0) + (header_value_mark != uint.max ? 1 : 0) + (
            url_mark != uint.max ? 1 : 0) + (body_mark != uint.max ? 1 : 0) + (
            status_mark != uint.max ? 1 : 0)) <= 1);

        mixin(CALLBACK_DATA_NOADVANCE("header_field")); //最后没找到
        mixin(CALLBACK_DATA_NOADVANCE("header_value"));
        mixin(CALLBACK_DATA_NOADVANCE("url"));
        mixin(CALLBACK_DATA_NOADVANCE("body"));
        mixin(CALLBACK_DATA_NOADVANCE("status"));

        return data.length;

    error:
        if (http_errno == HTTPParserErrno.HPE_OK)
        {
            http_errno = HTTPParserErrno.HPE_UNKNOWN;
        }

        return p;
    }

private:
    HTTPParserType _type = HTTPParserType.HTTP_BOTH;
    HTTPParserFlags flags = HTTPParserFlags.F_ZERO;
    HTTPParserState state;
    HTTPParserHeaderstates header_state;
    uint index;
    uint lenient_http_headers;
    uint nread;
    ulong content_length;
    ushort http_major;
    ushort http_minor;
    uint status_code; /* responses only */
    HTTPMethod method; /* requests only */
    HTTPParserErrno http_errno = HTTPParserErrno.HPE_OK;
    /* 1 = Upgrade header was present and the parser has exited because of that.
	 * 0 = No upgrade header present.
	 * Should be checked when http_parser_execute() returns in addition to
	 * error checking.
	 */
    bool upgrade;

    bool _isHandle = false;

    bool _skipBody = false;

    uint _maxHeaderSize = 1024;

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
        if (status_code / 100 == 1 || /* 1xx e.g. Continue */
                status_code == 204 || /* No Content */
                status_code == 304
                || /* Not Modified */
                flags & HTTPParserFlags.F_SKIPBODY)
        { /* response to a HEAD request */
            return false;
        }

        if ((flags & HTTPParserFlags.F_CHUNKED) || content_length != ULLONG_MAX)
        {
            return false;
        }

        return true;
    }

    pragma(inline)
    bool httpShouldKeepAlive()
    {
        if (http_major > 0 && http_minor > 0)
        {
            /* HTTP/1.1 */
            if (flags & HTTPParserFlags.F_CONNECTION_CLOSE)
            {
                return false;
            }
        }
        else
        {
            /* HTTP/1.0 or earlier */
            if (!(flags & HTTPParserFlags.F_CONNECTION_KEEP_ALIVE))
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
			http_errno = HTTPParserErrno.HPE_STRICT;                                     
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
    string _s = " {if (_on_" ~ code ~ " != null){
               _on_" ~ code ~ "(this); if(!handleIng){
                http_errno = HTTPParserErrno.HPE_CB_" ~ code ~ ";
                return  p + 1;}} }";
    return _s;
}

string CALLBACK_NOTIFY_NOADVANCE(string code)
{
    string _s = " {if (_on_" ~ code ~ " != null){
	               _on_" ~ code ~ "(this); if(!handleIng){
	                http_errno = HTTPParserErrno.HPE_CB_" ~ code ~ ";
	                return  p;} }}";
    return _s;
}

string CALLBACK_DATA(string code)
{
    string _s = "{ if(" ~ code ~ "_mark != uint.max && _on_" ~ code ~ " != null){
                ulong len = (p - " ~ code ~ "_mark) ;
                
                if(len > 0) {  
               /* writeln(\"CALLBACK_DATA at  \",__LINE__, \"  " ~ code ~ "\");*/
                ubyte[]  _data =  data[" ~ code ~ "_mark..p];
                _on_" ~ code ~ "(this,_data,true);
                if (!handleIng){
                    http_errno = HTTPParserErrno.HPE_CB_" ~ code ~ ";
                    return  p + 1;}} }" ~ code ~ "_mark = uint.max;}";
    return _s;
}

string CALLBACK_DATA_NOADVANCE(string code)
{
    string _s = "{ if(" ~ code ~ "_mark != uint.max && _on_" ~ code ~ " != null){
                ulong len = (p - " ~ code ~ "_mark) ;
                if(len > 0) {  
                 /*writeln(\"CALLBACK_DATA_NOADVANCE at  \",__LINE__, \"  " ~ code ~ "\");*/
                ubyte[]  _data = data[" ~ code ~ "_mark..p];
                _on_" ~ code ~ "(this,_data,false);
                if (!handleIng){
                    http_errno = HTTPParserErrno.HPE_CB_" ~ code ~ ";
                return  p;} }}" ~ code ~ "_mark = uint.max;}";
    return _s;
}

unittest
{
    import std.stdio;
    import std.functional;

    writeln("\n\n\n");

    void on_message_begin(HTTPParser)
    {
        writeln("_on_message_begin");
        writeln(" ");
    }

    void on_url(HTTPParser par, ubyte[] data, bool adv)
    {
        writeln("_on_url, is NOADVANCE = ", adv);
        writeln("\" ", cast(string) data, " \"");
        writeln("HTTPMethod is = ", par.methodString);
        writeln(" ");
    }

    void on_status(HTTPParser par, ubyte[] data, bool adv)
    {
        writeln("_on_status, is NOADVANCE = ", adv);
        writeln("\" ", cast(string) data, " \"");
        writeln(" ");
    }

    void on_header_field(HTTPParser par, ubyte[] data, bool adv)
    {
        static bool frist = true;
        writeln("_on_header_field, is NOADVANCE = ", adv);
        writeln("len = ", data.length);
        writeln("\" ", cast(string) data, " \"");
        if (frist)
        {
            writeln("\t http_major", par.major);
            writeln("\t http_minor", par.minor);
            frist = false;
        }
        writeln(" ");
    }

    void on_header_value(HTTPParser par, ubyte[] data, bool adv)
    {
        writeln("_on_header_value, is NOADVANCE = ", adv);
        writeln("\" ", cast(string) data, " \"");
        writeln(" ");
    }

    void on_headers_complete(HTTPParser par)
    {
        writeln("_on_headers_complete");
        writeln(" ");
    }

    void on_body(HTTPParser par, ubyte[] data, bool adv)
    {
        writeln("_on_body, is NOADVANCE = ", adv);
        writeln("\" ", cast(string) data, " \"");
        writeln(" ");
    }

    void on_message_complete(HTTPParser par)
    {
        writeln("_on_message_complete");
        writeln(" ");
    }

    void on_chunk_header(HTTPParser par)
    {
        writeln("_on_chunk_header");
        writeln(" ");
    }

    void on_chunk_complete(HTTPParser par)
    {
        writeln("_on_chunk_complete");
        writeln(" ");
    }

    string data = "GET /test HTTP/1.1\r\nUser-Agent: curl/7.18.0 (i486-pc-linux-gnu) libcurl/7.18.0 OpenSSL/0.9.8g zlib/1.2.3.3 libidn/1.1\r\nHost:0.0.0.0=5000\r\nAccept: */*\r\n\r\n";
    HTTPParser par = new HTTPParser();
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
