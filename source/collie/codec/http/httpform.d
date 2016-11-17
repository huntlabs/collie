module collie.codec.http.httpform;

import collie.buffer;
import std.array;
import std.string;
import std.exception;
import std.experimental.logger;

class HTTPForm
{
	alias StringArray = string[];
	enum ubyte[2] ENDMYITLFORM = ['-','-']; 

	final class FormFile
	{
		string fileName;
		string contentType;
		ulong startSize = 0;
		ulong length = 0;
//		ubyte[] data;
	private : 
		this(){}
	}
	
	this(string contype,  Buffer body_)
	{
		if (contype.indexOf("multipart/form-data") > -1)
		{
			auto tmp = parseKeyValues(contype, "; ");
			auto strBoundary = tmp.get("boundary", "").strip();
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
		//ubyte[] buf = new ubyte[buffer.length];
		Appender!(ubyte[]) buf = appender!(ubyte[]);
		buffer.readAll((in ubyte[] data){
				buf.put(data);
			});
		parseFromKeyValues(cast(string) buf.data);
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
		/*if("content-disposition" !in header){
		return false;
		}*/
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
			fp.fileName = filename;
			fp.contentType = header.get("content-type", "");
			fp.startSize = buffer.readPos();
			//auto value = appender!(ubyte[])();
			buffer.readUtil(boundary,(in ubyte[] rdata) {
					fp.length += rdata.length;
					//value.put(rdata);
				});
			//fp.data = value.data;
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
		enforce(ub == cast(ubyte[]) "\r\n", "showed be \\r\\n");
		return true;
	}
	
	void parseFromKeyValues(string raw, string split1 = "&", string spilt2 = "=")
	{
		import std.uri;
		if (raw.length == 0)
			return ;
		string[] pairs = raw.strip.split(split1);
		foreach (string pair; pairs)
		{
			string[] parts = pair.split(spilt2);
			
			// Accept formats a=b/a=b=c=d/a
			if (parts.length == 1)
			{
				string key = parts[0];
				_forms[key] ~= "";
			}
			else if (parts.length > 1)
			{
				string key = parts[0];
				string value = pair[parts[0].length + 1 .. $];
				_forms[key] ~= decodeComponent(value);
			}
		}
	}
private:
	bool _vaild = true;
	StringArray[string] _forms;
	FormFile[string] _files;

}

string[string] parseKeyValues(string raw, string split1 = "&", string spilt2 = "=")
{
	import std.uri;
	
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
