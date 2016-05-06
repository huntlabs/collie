module collie.codec.http.header;

import std.conv;
import std.uri;
import std.string;

public import collie.codec.http.parsertype;
import collie.codec.http.config;

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

class HTTPHeader
{
    this(HTTPHeaderType type)
    {
        _type = type;
    }

    ~this()
    {
        //	destroy(_header);
        _header = null;
    }

    @property HTTPHeaderType type() const
    {
        return _type;
    }

    @property void type(HTTPHeaderType type)
    {
        _type = type;
    }
    // REQUEST
    @property HTTPMethod method() const
    {
        return _method;
    }

    @property void method(HTTPMethod met)
    {
        _method = met;
    }

    @property string methodString() const
    {
        return method_strings[_method];
    }

    @property bool upgrade() const
    {
        return _upgrade;
    }

    @property int statusCode() const
    {
        return _statuCode;
    } // RESPONSE only
    @property void statusCode(int code)
    {
        _statuCode = code;
    }

    @property httpVersion() const
    {
        return _hversion;
    }

    @property httpVersion(HTTPVersion ver)
    {
        _hversion = ver;
    }

    @property requestString() const
    {
        return _queryString;
    }

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
    }

    @property queryString() const
    {
        if (_fileStart + 1 < _queryString.length)
            return _queryString[(_fileStart + 1) .. $];
        else
            return "";
    }

    @property path() const
    {
        return decode(_queryString[0 .. _fileStart]);
    }

    @property string[string] queryMap() const
    {
        if (_fileStart == cast(uint) _queryString.length)
            return string[string].init;
        return parseKeyValues(queryString);
    }

    @property const(string[string]) headerMap() const
    {
        return _header;
    }

    @property host() const
    {
        return _header["Host"];
    }

    void setHeaderValue(T)(string key, T value)
    {
        key = toLower(key.strip); //capitalizeHeader(strip(key));//
        _header[key] = to!string(value);
    }

    string getHeaderValue(string key) const
    {
        key = toLower(key.strip); //capitalizeHeader(strip(key));//
        return _header.get(key, "");
    }

    void removeHeaderKey(string key)
    {
        key = toLower(key.strip); //capitalizeHeader(key);//
        _header.remove(key);
    }

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

    bool isInVaild() const
    {
        return (_method == HTTPMethod.HTTP_INVAILD && _statuCode == -1);
    } // 无效的
package:
    void clear()
    {
        _statuCode = -1;
        _method = HTTPMethod.HTTP_INVAILD;
        _queryString = "";
        _fileStart = 0;
        _header.clear();
        //foreach(key; _header.keys)
        //_header.remove(key);  
    }

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
    string _queryString;
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
            string value = decode(pair[parts[0].length + 1 .. $]);
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
