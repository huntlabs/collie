module collie.codec.http.server.httpform;

import collie.buffer;
import std.array;
import std.string;
import std.exception;
import std.experimental.logger;
import collie.utils.string;
import collie.utils.vector;
import std.experimental.allocator.gc_allocator;
import std.uri;

class HTTPForm
{
	alias StringArray = string[];
	enum ubyte[2] ENDMYITLFORM = ['-','-']; 
	enum ubyte[2] LRLN = ['\r','\n']; 

	final class FormFile
	{
		@property fileName(){return _fileName;}
		@property contentType(){return _contentType;}
		@property fileSzie(){return _length;} 
		void read(size_t size,void delegate(in ubyte[] data) cback)
		{
			size = size > _length ? _length : size;
			_body.rest(_startSize);
			_body.read(size,cback);
		}
	private : 
		Buffer _body;
		size_t _startSize = 0;
		size_t _length = 0;
		string _fileName;
		string _contentType;
		this(){}
	}
	
	this(string contype,  Buffer body_)
	{
		if (contype.indexOf("multipart/form-data") > -1)
		{
			string strBoundary;
			splitNameValue(contype,';','=',(string key,string value){
					if(isSameIngnoreLowUp(strip(key),"boundary")) {
						strBoundary = value;
						return false;
					}
					return true;
				});
			if (strBoundary.length > 0)
			{
				if(strBoundary[0] == '\"')
					strBoundary = strBoundary[1..strBoundary.length -1];
				readMultiFrom(strBoundary, body_);
			}
		}
		else if (contype.indexOf("application/x-www-form-urlencoded") > -1)
		{
			readXform(body_);
		}
		else
		{
			_vaild = false;
		}
		body_.rest();
	}
	
	@property bool isVaild() const
	{
		return _vaild;
	}
	
	@property StringArray[string] formMap()
	{
		return _forms;
	}
	
	@property FormFile[string] fileMap()
	{
		return _files;
	}
	
	string getFromValue(string key)
	{
		StringArray aty;
		aty = _forms.get(key, aty);
		if(aty.length == 0)
			return "";
		else
			return aty[0];
	}
	
	StringArray getFromValueArray(string key)
	{
		StringArray aty;
		return _forms.get(key, aty);
	}
	
	auto getFileValue(string key) const
	{
		return   _files.get(key, null);
	}
	
protected:
	void readXform(Buffer buffer)
	{

		Vector!(ubyte,GCAllocator) buf;
		buf.reserve(buffer.length);
		buffer.readAll((in ubyte[] data){
				buf.insertBack(cast(ubyte[])data);
			});
		ubyte[] dt = buf.data(false);
		splitNameValue(cast(string)dt,'&','=',(string key, string value){
				if(value.length > 0)
					_forms[key] ~= decodeComponent(value);
				else
					_forms[key] ~= "";
				return true;
			});
	}
	
	void readMultiFrom(string brand, Buffer buffer)
	{
		buffer.rest();
		string brony = "--" ~ brand;
		string str;
		do{
			Appender!(ubyte[]) buf = appender!(ubyte[]);
			buffer.readLine((in ubyte[] data){
					buf.put(data);
				});
			auto sttr = cast(string)buf.data;
			str = sttr.strip;
			if(str.length == 0){
				continue;
			} else if(str == brony){
				break;
			}  else {
				return;
			}
		} while(true);

		brony = "\r\n" ~ brony;
		bool run;
		do
		{
			run = readMultiftomPart(buffer, cast(ubyte[]) brony);
		}
		while (run);
	}
	
	bool readMultiftomPart(Buffer buffer, ubyte[] boundary)
	{
		string[string] header;
		do {
			Appender!(ubyte[]) buf = appender!(ubyte[]);
			buffer.readLine((in ubyte[] data){
					buf.put(data);
				});
			ubyte[] line = buf.data;
			if(line.length == 0)
				break;
			auto pos = (cast(string) line).indexOf(":");
			if (pos <= 0 || pos == (line.length - 1))
				continue;
			string key = cast(string)(line[0 .. pos]);
			header[toLower(key.strip)] = (cast(string)(line[pos + 1 .. $])).strip;
		} while(true);
		string cd = header.get("content-disposition", "");
		if (cd.length == 0)
			return false;
		string name;
		auto pos = cd.indexOf("name=\"");
		if (pos >= 0)
		{
			cd = cd[pos + 6 .. $];
			pos = cd.indexOf("\"");
			name = cd[0 .. pos];
		}
		string filename;
		pos = cd.indexOf("filename=\"");
		if (pos >= 0)
		{
			cd = cd[pos + 10 .. $];
			pos = cd.indexOf("\"");
			filename = cd[0 .. pos];
		}
		if (filename.length > 0)
		{
			import std.array;
			FormFile fp = new FormFile;
			fp._fileName = filename;
			fp._contentType = header.get("content-type", "");
			fp._startSize = buffer.readPos();
			fp._body = buffer;
			buffer.readUtil(boundary,(in ubyte[] rdata) {
					fp._length += rdata.length;
				});
			_files[name] = fp;
		}
		else
		{
			import std.array;
			auto value = appender!(string)();
			buffer.readUtil(boundary, delegate(in ubyte[] rdata) {
					value.put(cast(string) rdata);
				});
			string stdr = value.data;
			_forms[name] ~= stdr;
			
		}
		ubyte[2] ub;
		bool frist = true;
		buffer.read(2,(in ubyte[] dt){
				switch(dt.length){
					case 2:
						ub[] = dt[];
						break;
					case 1:{
						if(frist){
							ub[0] = dt[0];
							frist = false;
						} else {
							ub[1] = dt[0];
						}
					}break;
					default:
						break;
				}
			});
		if (ub == ENDMYITLFORM)
		{
			return false;
		}
		enforce(ub == LRLN, "showed be \\r\\n");
		return true;
	}

private:
	bool _vaild = true;
	StringArray[string] _forms;
	FormFile[string] _files;
}