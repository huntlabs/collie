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
module collie.utils.exception;
import kiss.logger;
public import std.exception : basicExceptionCtors;

mixin template ExceptionBuild(string name, string parent = "")
{
	enum buildStr = "class " ~ name ~ "Exception : " ~ parent ~ "Exception { \n\t" ~ "mixin basicExceptionCtors;\n }";
	mixin(buildStr);
}

mixin template ThrowExceptionBuild()
{
	pragma(inline, true)
		void throwExceptionBuild(string name = "")(string msg = "",string file = __FILE__, size_t line = __LINE__ )
	{
		mixin("throw new " ~ name ~ "Exception(msg,file,line);");
	}
}

pragma(inline)
	void showException(bool gcfree = false,int line = __LINE__, string file = __FILE__,
		string funcName = __FUNCTION__)(Exception e) nothrow
{
	
	import std.exception;
	collectException(logError(e.toString));
	static if(gcfree){
		import collie.utils.memory;
		collectException(gcFree(e));
	}

}

string buildErroCodeException(T)() if(is(T == enum))
{
	string str = "mixin ExceptionBuild!(\"" ~ T.stringof ~ "\");\n";
	foreach(memberName; __traits(derivedMembers,T)){
		str ~= "mixin ExceptionBuild!(\"" ~ memberName ~ "\", \"" ~ T.stringof ~ "\");\n";
	}
	return str;
}


version(unittest)
{
	enum Test{
		MyTest1,
		MyTest2,
	}
	//mixin ExceptionBuild!"MyTest1";
	//mixin ExceptionBuild!"MyTest2";
	mixin(buildErroCodeException!Test());
	mixin ThrowExceptionBuild;
}

unittest
{
	import std.stdio;
	import std.exception;
	auto e = collectException!TestException(throwExceptionBuild!"Test"("test Exception"));
	assert(e !is null);
	auto e1 = collectException!MyTest1Exception(throwExceptionBuild!"MyTest1"("test Exception"));
	assert(e1 !is null);
	auto e2 = collectException!MyTest2Exception(throwExceptionBuild!"MyTest2"("test Exception"));
	assert(e2 !is null);
}