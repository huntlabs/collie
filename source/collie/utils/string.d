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
module collie.utils.string;

import std.array;
import std.string;
import std.traits;
import std.range;

void splitNameValue(TChar, Char, bool caseSensitive = true)(TChar[] data, in Char pDelim, in Char vDelim, 
	scope bool delegate(TChar[],TChar[]) callback) if(isSomeChar!(Unqual!TChar) && isSomeChar!(Unqual!Char) )
{
	enum size_t blen = 1;
	enum size_t elen = 1;
	const dchar pairDelim = pDelim;
	const dchar valueDelim = vDelim;
	
	mixin(TSplitNameValue!());
}

void splitNameValue(TChar, Char,bool caseSensitive = true)(TChar[] data, const(Char)[] pairDelim, const(Char)[] valueDelim,
	scope bool delegate(TChar[],TChar[]) callback) if(isSomeChar!(Unqual!TChar) && isSomeChar!(Unqual!Char) )
{
	const size_t blen = pairDelim.length;
	const size_t elen = valueDelim.length;
	
	mixin(TSplitNameValue!());
	
}

bool isSameIngnoreLowUp(TChar)(TChar[] s1,TChar[] s2) if(isSomeChar!(Unqual!TChar))
{
	import std.uni;
	if(s1.length != s2.length) return false;
	for(size_t i = 0; i < s1.length; ++i)
	{
		dchar c1 = toLower(s1[i]);
		dchar c2 = toLower(s2[i]);
		if(c1 != c2)
			return false;
	}
	return true;
}

private:
template TSplitNameValue()
{
	enum TSplitNameValue = q{
		static if(caseSensitive)
			enum thecaseSensitive = CaseSensitive.yes;
		else
			enum thecaseSensitive = CaseSensitive.no;
		while(data.length > 0)
		{
			auto index = data.indexOf(pairDelim,thecaseSensitive);
			string keyValue;
			if(index < 0){
				keyValue = data;
				data.length = 0;
			} else {
				keyValue = data[0..index];
				data = data[(index + blen) .. $];
			}
			if(keyValue.length == 0)
				continue;
			auto valueDelimPos = keyValue.indexOf(valueDelim,thecaseSensitive);
			if(valueDelimPos < 0){
				if(!callback(keyValue,string.init))
					return;
			} else {
				auto name = keyValue[0..valueDelimPos];
				auto value = keyValue[(valueDelimPos + elen)..$];
				if(!callback(name,value))
					return;
			}
		}
	};
} 

unittest
{
	import std.stdio;
	string hh = "ggujg=wee&ggg=ytgy&ggg0HH&hjkhk=00";
	string hh2 = "ggujg$=wee&$ggg=ytgy&$ggg0HH&hjkhk$=00";
	
	splitNameValue(hh,'&','=',(string key,string value){
			writeln("1.   ", key, "  ", value);
			return true;
		});
	
	splitNameValue(hh2,"&$","$=",(string key,string value){
			writeln("2.   ", key, "  ", value);
			return true;
		});
	
	writeln(isSameIngnoreLowUp("AAA12345", "aaa12345"));
}