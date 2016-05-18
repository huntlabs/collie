module collie.codec.http.response;

import core.stdc.string : memcpy;

import std.string;cokkies
import std.array;
import std.conv;

import collie.codec.http.header;
import collie.codec.http.request;
import collie.codec.http.config;
import collie.buffer.sectionbuffer;

enum XPoweredBy = "collied ( " ~ getComplierName() ~ " )  http://collied.org/";

string getComplierName()
{
    import compiler = std.compiler;

    string name;
    final switch (compiler.vendor)
    {
    case compiler.Vendor.unknown:
        name = "UnKnow";
        break;
    case compiler.Vendor.digitalMars:
        name = "DMD";
        break;
    case compiler.Vendor.gnu:
        name = "GDC";
        break;
    case compiler.Vendor.llvm:
        name = "LDC";
        break;
    case compiler.Vendor.dotNET:
        name = "D.NET";
        break;
    case compiler.Vendor.sdc:
        name = "SDC";
        break;
    }
    name = name ~ " / " ~ to!string(compiler.version_major) ~ "." ~ to!string(
        compiler.version_minor);
    name ~= ".";
    name ~= to!string(compiler.D_major);
    return name;
}

alias CallBackResponse = void delegate(HTTPResponse);
alias ResponseSend = void delegate(HTTPResponse, string, ulong begin);

class HTTPResponse
{
    this(HTTPConfig config = httpConfig)
    {
        _config = config;
        _header = new HTTPHeader(HTTPHeaderType.HTTP_RESPONSE);
        _header.statusCode = 200;
        _body = new SectionBuffer(_config.responseBodyStectionSize, httpAllocator);
    }

    ~this()
    {
        _body.destroy;
        _body = null;
        _header.destroy;
        _header = null;
    }

    final @property Header()
    {
        return _header;
    }

    final @property Body()
    {
        return _body;
    }

    final bool append(ubyte[] data)
    {
        if (_done)
            return false;
        _body.write(data);
        return true;
    }

    final bool done()
    {
        return done(null, 0);
    }

    final bool done(string file)
    {
        return done(file, 0);
    }

    final bool done(string file, ulong begin)
    {
        if (!_done && _resDone)
        {
            _done = true;
            _resDone(this, file, begin);
            return true;
        }
        return false;
    }

    final void close()
    {
        if (!_done && _resClose)
            _resClose(this);
        _done = true;
    }

    final @property sentCall(ResponseSend cback)
    {
        _resDone = cback;
    }

    final @property closeCall(CallBackResponse cback)
    {
        _resClose = cback;
    }

    static void generateHeader(HTTPResponse resp, SectionBuffer buffer)
    {
        // Only send a response body if the request wasn't HEAD
        if (resp._header.statusCode == -1)
        {
            resp._header.statusCode = 200;
        }

        resp._header.removeHeaderKey("Transfer-Encoding");
        //resp._header.setHeaderValue("Content-Length",length);
        resp._header.setHeaderValue("X-Powered-By", XPoweredBy);

        buffer.write(cast(ubyte[]) "HTTP/1.1 ");
        buffer.write(cast(ubyte[])(to!string(resp._header.statusCode)));
        buffer.write(cast(ubyte[]) " ");
        buffer.write(cast(ubyte[])(statusText(resp._header.statusCode)));
        buffer.write(cast(ubyte[]) "\r\n");

        foreach (name, value; resp._header.headerMap)
        {
            buffer.write(cast(ubyte[]) name);
            buffer.write(cast(ubyte[]) ": ");
            buffer.write(cast(ubyte[]) value);
            buffer.write(cast(ubyte[]) "\r\n");
        }
        import std.container.array;
        Array!string cookies;
        resp._header.swapSetedCookieString(cookies);
        foreach (value; cookies)
        {
             buffer.write(cast(ubyte[]) "set-cookie: ");
             buffer.write(cast(ubyte[]) value);
             buffer.write(cast(ubyte[]) "\r\n");
        }

        buffer.write(cast(ubyte[]) "\r\n");
    }

package:
    final void clear()
    {
        _header.clear();
        _done = false;
        _body.clear();
    }

    bool _done = false;
private:
    HTTPHeader _header;
    SectionBuffer _body;
    ResponseSend _resDone;
    CallBackResponse _resClose;
    HTTPConfig _config;
}

private string statusText(int code)
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
