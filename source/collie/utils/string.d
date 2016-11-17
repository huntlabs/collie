module collie.utils.string;

import std.array;
import std.string;
import std.traits;
import std.range;

void splitNameValue(Range)(Range data, dchar pairDelim, dchar valueDelim, void delegate(string,string) callback)
	if (isInputRange!Range && isSomeChar!(ElementEncodingType!Range) &&
		!isConvertibleToString!Range)
{
	while(data.length > 0)
	{
		auto index = data.indexOf(pairDelim);
		string keyValue;
		if(index < 0){
			keyValue = data;
			data.length = 0;
		} else {
			keyValue = data[0..index];
			data = data[(index + 1) .. $];
		}
		if(keyValue.length == 0)
			continue;
		size_t valueDelimPos = keyValue.indexOf(valueDelim);
		if(valueDelimPos < 0){
			callback(keyValue,string.init);
		} else {
			string name = keyValue[0..valueDelimPos];
			string value = keyValue[(valueDelimPos + 1)..$];
			callback(name,value);
		}
	}
}