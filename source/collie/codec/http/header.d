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
module collie.codec.http.header;

import std.conv;
import std.uri;
import std.string;
import std.experimental.allocator.gc_allocator;

public import collie.codec.http.parsertype;
import collie.codec.http.config;
import collie.utils.vector;

enum HTTPHeaderType
{
    HTTP_REQUEST = HTTPParserType.HTTP_REQUEST,
    HTTP_RESPONSE = HTTPParserType.HTTP_RESPONSE,
}

enum HTTPVersion
{
    HTTP1_0,
    HTTP1_1,
    HTTP2 //暂时不支持
}

final class HTTPHeader
{
    alias CookieVector = Vector!(string, false, GCAllocator);

    this(HTTPHeaderType type)
    {
        _type = type;
    }

    ~this()
    {
        //	destroy(_header);
        _header = null;
    }

    pragma(inline,true)
    @property HTTPHeaderType type() const
    {
        return _type;
    }

    pragma(inline)
    @property void type(HTTPHeaderType type)
    {
        _type = type;
    }
    // REQUEST
    pragma(inline,true)
    @property HTTPMethod method() const
    {
        return _method;
    }

    pragma(inline)
    @property void method(HTTPMethod met)
    {
        _method = met;
    }

    pragma(inline,true)
    @property string methodString() const
    {
        return method_strings[_method];
    }

    pragma(inline,true)
    @property bool upgrade() const
    {
        return _upgrade;
    }

    pragma(inline,true)
    @property int statusCode() const
    {
        return _statuCode;
    }

    // RESPONSE only
    pragma(inline)
    @property void statusCode(int code)
    {
        _statuCode = code;
    }

    pragma(inline,true)
    @property httpVersion() const
    {
        return _hversion;
    }

    pragma(inline)
    @property httpVersion(HTTPVersion ver)
    {
        _hversion = ver;
    }

    pragma(inline,true)
    @property requestString() const
    {
        return _queryString;
    }

    pragma(inline)
    @property requestString(string str)
    {
        _queryString = str;
        auto idx = _queryString.indexOf('?');
        if (idx != -1)
        {
            _fileStart = cast(uint) idx;
        }
        else
        {
            _fileStart = cast(uint) _queryString.length;
        }
		import std.path;
		_path = buildNormalizedPath(decode(_queryString[0 .. _fileStart]));
		version (Windows){
			import std.array;
			_path = replace(_path,"\\", "/");
		}
    }

    @property queryString() const
    {
        if (_fileStart + 1 < _queryString.length)
            return _queryString[(_fileStart + 1) .. $];
        else
            return "";
    }

    pragma(inline,true)
    @property path() const
    {
		return _path;
    }

    @property string[string] queryMap() const
    {
        if (_fileStart == cast(uint) _queryString.length)
            return string[string].init;
        return parseKeyValues(queryString);
    }

    pragma(inline,true)
    @property const(string[string]) headerMap() const
    {
        return _header;
    }

    pragma(inline,true)
    @property host() const
    {
        return _header["host"];
    }

    pragma(inline)
    void setHeaderValue(T)(string key, T value)
    {
        key = toLower(key.strip); //capitalizeHeader(strip(key));//
        if (key == "set-cookie")
        {
            setCookieString(to!string(value));
        }
        else
        {
            _header[key] = to!string(value);
        }
    }

    pragma(inline)
    void setCookieString(string value)
    {
        _setCookies.insertBack(value);
    }

    pragma(inline,true)
    CookieVector getSetedCookieString()
    {
        return _setCookies;
    }

    pragma(inline)
    void swapSetedCookieString(ref CookieVector array)
    {
        import std.algorithm : swap;

        swap(_setCookies, array);
    }

    pragma(inline)
    string getHeaderValue(string key) const
    {
        key = toLower(key.strip); //capitalizeHeader(strip(key));//
        return _header.get(key, "");
    }

    pragma(inline)
    void removeHeaderKey(string key)
    {
        key = toLower(key.strip); //capitalizeHeader(key);//
        _header.remove(key);
    }

    pragma(inline)
    string contentType(bool toLow = false)() const
    {
        string type = getHeaderValue("Content-Type");
        if (type.length > 0)
        {
            string[] pairs = raw.split(';');
            type = pairs[0].strip();
            static if (tolow)
            {
                type = toLower(type);
            }
        }
        return type;
    }

    pragma(inline,true)
    bool isInVaild() const
    {
        return (_method == HTTPMethod.HTTP_INVAILD && _statuCode == -1);
    } // 无效的
//package:
    pragma(inline,true)
    void clear()
    {
        _statuCode = -1;
        _method = HTTPMethod.HTTP_INVAILD;
        _queryString = "";
        _fileStart = 0;
        _header.clear();
        _setCookies.clear();
    }

    pragma(inline)
    @property void upgrade(bool up)
    {
        _upgrade = up;
    }

private:
    HTTPMethod _method = HTTPMethod.HTTP_INVAILD;
    int _statuCode = -1;
    HTTPHeaderType _type;
    HTTPVersion _hversion;
    string[string] _header;
    CookieVector _setCookies;
    string _queryString;
	string _path;
    bool _upgrade = false;
    uint _fileStart;
}

string[string] parseKeyValues(string raw, string split1 = "&", string spilt2 = "=")
{

    string[string] map;
    if (raw.length == 0)
        return map;
    string[] pairs = raw.strip.split(split1);
    foreach (string pair; pairs)
    {
        string[] parts = pair.split(spilt2);

        // Accept formats a=b/a=b=c=d/a
        if (parts.length == 1)
        {
            string key = decode(parts[0]);
            map[key] = "";
        }
        else if (parts.length > 1)
        {
            string key = decode(parts[0]);
            string value = decodeComponent(pair[parts[0].length + 1 .. $]);
            map[key] = value;
        }
    }
    return map;
}

string capitalizeHeader(string name)
{
    string[] parts = name.split("-");
    for (int i = 0; i < parts.length; i++)
    {
        parts[i] = parts[i].capitalize;
    }
    return join(parts, "-");
}
