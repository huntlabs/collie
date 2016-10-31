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
module collie.buffer;

interface Buffer
{
	@property bool eof() const;
	size_t read(size_t size, void delegate(in ubyte[]) cback);
	size_t write(in ubyte[] data);
	void rest(size_t size = 0);
	@property size_t length() const;

	size_t readLine(void delegate(in ubyte[]) cback); //回调模式，数据不copy
	
	size_t readAll(void delegate(in ubyte[]) cback);
	
	size_t readUtil(in ubyte[] data, void delegate(in ubyte[]) cback);

	size_t readPos();
}
