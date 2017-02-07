module collie.codec.http.headers;

import collie.utils.string;
import collie.utils.vector;
import core.stdc.string;
import std.string;
import std.array;

public import collie.codec.http.headers.httpcommonheaders;
public import collie.codec.http.headers.httpmethod;

struct HTTPHeaders
{
	alias HVector = Vector!(string);
	enum kInitialVectorReserve = 32;
	
	/**
   * Remove all instances of the given header, returning true if anything was
   * removed and false if this header didn't exist in our set.
   */
	bool remove(string name){
		HTTPHeaderCode code = headersHash(name);
		if(code != HTTPHeaderCode.OTHER)
			return remove(code);
		bool removed = false;
		for(size_t i = 0; i < _headersNames.length; ++i){
			if(_codes[i] != HTTPHeaderCode.OTHER) continue;
			if(isSameIngnoreLowUp(name,_headersNames[i])){
				_codes[i] = HTTPHeaderCode.NONE;
				_headersNames[i] = null;
				_headerValues[i] = null;
				_deletedCount ++;
				removed = true;
			}
		}
		return removed;
	}

	bool remove(HTTPHeaderCode code){
		bool removed = false;
		HTTPHeaderCode[] codes = _codes.data(false);
		HTTPHeaderCode * ptr = codes.ptr;
		const size_t len = codes.length;
		while(true)
		{
			size_t tlen = len - (ptr - codes.ptr);
			ptr = cast(HTTPHeaderCode *)memchr(ptr,code,tlen);
			if(ptr is null)
				break;
			tlen = ptr - codes.ptr;
			ptr ++;
			_codes[tlen] = HTTPHeaderCode.NONE;
			_headersNames[tlen] = null;
			_headerValues[tlen] = null;
			_deletedCount ++;
			removed = true;
		}
		return removed;
	}

	void add(string name, string value)
	in{
		assert(name.length > 0);
	}
	body{
		HTTPHeaderCode code = headersHash(name);
		_codes.insertBack(code);
		_headersNames.insertBack((code == HTTPHeaderCode.OTHER) ? name : HTTPHeaderCodeName[code]);
		_headerValues.insertBack(value);

	}
	void add(HTTPHeaderCode code, string value)
	{
		if(code == HTTPHeaderCode.OTHER || code > HTTPHeaderCode.SEC_WEBSOCKET_ACCEPT)
			return;
		_codes.insertBack(code);
		_headersNames.insertBack(HTTPHeaderCodeName[code]);
		_headerValues.insertBack(value);
	}

	void set(string name,string value)
	{
		remove(name);
		add(name, value);
	}

	void set(HTTPHeaderCode code, string value)
	{
		remove(code);
		add(code, value);
	}

	bool exists(string name)
	{
		HTTPHeaderCode code = headersHash(name);
		if(code != HTTPHeaderCode.OTHER)
			return exists(code);
		for(size_t i = 0; i < _headersNames.length; ++i){
			if(_codes[i] != HTTPHeaderCode.OTHER) continue;
			if(isSameIngnoreLowUp(name,_headersNames[i])){
				return true;
			}
		}
		return false;
	}

	bool exists(HTTPHeaderCode code)
	{
		HTTPHeaderCode[] codes = _codes.data(false);
		return memchr(codes.ptr,code,codes.length) != null;
	}

	void removeAll()
	{
		_codes.clear();
		_headersNames.clear();
		_headerValues.clear();
		_deletedCount = 0;
	}

	int opApply(scope int delegate(string name,string value) opeartions)
	{
		int result = 0;
		for(size_t i = 0; i < _headersNames.length; ++i)
		{
			result = opeartions(_headersNames[i], _headerValues[i]);
			if(result)
				break;
		}
		return result;
	}

	int opApply(scope int delegate(HTTPHeaderCode code,string name,string value) opeartions)
	{
		int result = 0;
		for(size_t i = 0; i < _headersNames.length; ++i)
		{
			result = opeartions(_codes[i],_headersNames[i], _headerValues[i]);
			if(result)
				break;
		}
		return result;
	}

	HTTPHeaders dub()
	{
		HTTPHeaders header;
		copyTo(header);
		return header;
	}

	void copyTo(ref HTTPHeaders header)
	{
		foreach(code,name,value; this)
		{
			if(code == HTTPHeaderCode.NONE) continue;
			if(code == HTTPHeaderCode.OTHER)
				header.add(name,value);
			else
				header.add(code,value);
		}
	}
	/**
   * Get the total number of headers.
   */
	size_t size() const{
		return _codes.length - _deletedCount;
	}
	/**
   * combine all the value for this header into a string
   */
	string combine(string separator = ", ")
	{
		Appender!string data = appender!string();
		bool frist = true;
		foreach(code,name,value; this)
		{
			if(code == HTTPHeaderCode.NONE) continue;
			if(frist) {
				data.put(value);
				frist = false;
			} else {
				data.put(separator);
				data.put(value);
			}
		}
		return data.data;
	}

	size_t getNumberOfValues(string name)
	{
		HTTPHeaderCode code = headersHash(name);
		if(code != HTTPHeaderCode.OTHER)
			return remove(code);
		size_t index = 0;
		for(size_t i = 0; i < _headersNames.length; ++i){
			if(_codes[i] != HTTPHeaderCode.OTHER) continue;
			if(isSameIngnoreLowUp(name,_headersNames[i])){
				++index;
			}
		}
		return index;
	}

	size_t getNumberOfValues(HTTPHeaderCode code)
	{
		size_t index = 0;
		HTTPHeaderCode[] codes = _codes.data(false);
		HTTPHeaderCode * ptr = codes.ptr;
		const size_t len = codes.length;
		while(true)
		{
			size_t tlen = len - (ptr - codes.ptr);
			ptr = cast(HTTPHeaderCode *)memchr(ptr,code,tlen);
			if(ptr is null)
				break;
			ptr ++;
			++ index;
		}
		return index;
	}

	string getSingleOrEmpty(string  name)  {
		HTTPHeaderCode code = headersHash(name);
		if(code != HTTPHeaderCode.OTHER)
			return getSingleOrEmpty(code);
		for(size_t i = 0; i < _headersNames.length; ++i){
			if(_codes[i] != HTTPHeaderCode.OTHER) continue;
			if(isSameIngnoreLowUp(name,_headersNames[i])){
				return _headerValues[i];
			}
		}
		return string.init;
	}

	string getSingleOrEmpty(HTTPHeaderCode code)  {
		HTTPHeaderCode[] codes = _codes.data(false);
		HTTPHeaderCode * ptr = cast(HTTPHeaderCode *)memchr(codes.ptr,code,codes.length);
		if(ptr !is null){
			size_t index = ptr - codes.ptr;
			return _headerValues[index];
		}
		return string.init;
	}

	/**
   * Process the ordered list of values for the given header name:
   * for each value, the function/functor/lambda-expression given as the second
   * parameter will be executed. It should take one const string & parameter
   * and return bool (false to keep processing, true to stop it). Example use:
   *     hdrs.forEachValueOfHeader("someheader", [&] (const string& val) {
   *       std::cout << val;
   *       return false;
   *     });
   * This method returns true if processing was stopped (by func returning
   * true), and false otherwise.
   */
	alias LAMBDA = bool delegate(string value);
	bool forEachValueOfHeader(string name,scope LAMBDA func)
	{
		HTTPHeaderCode code = headersHash(name);
		if(code != HTTPHeaderCode.OTHER)
			return forEachValueOfHeader(code,func);
		size_t index = 0;
		for(size_t i = 0; i < _headersNames.length; ++i){
			if(_codes[i] != HTTPHeaderCode.OTHER) continue;
			if(isSameIngnoreLowUp(name,_headersNames[i])){
				if(func(_headerValues[i]))
					return true;
			}
		}
		return false;
	}

	bool forEachValueOfHeader(HTTPHeaderCode code,scope LAMBDA func)
	{
		size_t index = 0;
		HTTPHeaderCode[] codes = _codes.data(false);
		HTTPHeaderCode * ptr = codes.ptr;
		const size_t len = codes.length;
		while(true)
		{
			size_t tlen = len - (ptr - codes.ptr);
			ptr = cast(HTTPHeaderCode *)memchr(ptr,code,tlen);
			if(ptr is null)
				break;
			tlen = ptr - codes.ptr;
			ptr ++;
			if(func(_headerValues[tlen]))
				return true;
		}
		return false;
	}
private:
	Vector!(HTTPHeaderCode) _codes ;// = Vector!(HTTPHeaderCode)(2);
	HVector _headersNames ;
	HVector _headerValues ;
	size_t _deletedCount = 0;
}