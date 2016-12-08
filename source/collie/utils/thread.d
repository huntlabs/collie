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
module collie.utils.thread;

public import core.thread;
import std.exception;

pragma(inline)
Thread currentThread() nothrow @trusted
{
	auto th = Thread.getThis();
	if(th is null){
		collectException(thread_attachThis(), th);
	}
	return th;
}

unittest{
	import std.stdio;
	writeln("currentThread().id ------------- " , currentThread().id);
}