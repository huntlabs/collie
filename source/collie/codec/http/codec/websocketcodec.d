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
module collie.codec.http.codec.websocketcodec;

import collie.codec.http.codec.httpcodec;
import collie.codec.http.httptansaction;
import std.bitmanip;
import collie.codec.http.codec.wsframe;
import collie.codec.http.httpmessage;
import collie.codec.http.errocode;
import std.conv;

enum FRAME_SIZE_IN_BYTES = 512 * 512 * 2; //maximum size of a frame when sending a message


class WebsocketCodec : HTTPCodec
{
	enum ProcessingState
	{
		PS_READ_HEADER,
		PS_READ_Do_LENGTH,
		PS_READ_PAYLOAD_LENGTH_1,
		PS_READ_PAYLOAD_LENGTH,
		PS_READ_BIG_PAYLOAD_LENGTH,
		PS_READ_BIG_PAYLOAD_LENGTH_1,
		PS_READ_MASK,
		PS_READ_MASK_1,
		PS_READ_PAYLOAD
	}

	this(TransportDirection direc, HTTPTransaction txn)
	{
		_transportDirection = direc;
		_transaction = txn;
	}

	override CodecProtocol getProtocol() {
		return CodecProtocol.WEBSOCKET;
	}

	override void onConnectClose()
	{
		if(_transaction){
			_transaction.onErro(HTTPErrorCode.REMOTE_CLOSED);
			_transaction.handler = null;
			_transaction.transport = null;
		}
	}
	
	override void onTimeOut()
	{
		if(_transaction){
			_transaction.onErro(HTTPErrorCode.TIME_OUT);
		}
	}
	
	override void detach(HTTPTransaction txn)
	{
		if(txn is _transaction)
			_transaction = null;
	}

	
	override TransportDirection getTransportDirection()
	{
		return _transportDirection;
	}
	
	override StreamID createStream() {
		return 0;
	}
	
	override bool isBusy() {
		return !_finished;
	}
	
	override bool shouldClose()
	{
		return _shouldClose;
	}
	
	override void setParserPaused(bool paused){}
	
	override void setCallback(CallBack callback) {
		_callback = callback;
	}
	
	override size_t onIngress(ubyte[] buf)
	{
		readFrame(buf);
		return buf.length;
	}
	
	override size_t generateHeader(
		HTTPTransaction txn,
		HTTPMessage msg,
		ref HVector buffer,
		bool eom = false)
	{
		return 0;
	}
	
	override size_t generateBody(HTTPTransaction txn,
		ref HVector chain,
		bool eom)
	{
		return 0;
	}
	
	override size_t generateChunkHeader(
		HTTPTransaction txn,
		ref HVector buffer,
		size_t length)
	{
		return 0;
	}
	
	
	override size_t generateChunkTerminator(
		HTTPTransaction txn,
		ref HVector buffer)
	{
		return 0;
	}
	
	override size_t generateEOM(HTTPTransaction txn,
		ref HVector buffer)
	{
		return 0;
	}

	override size_t  generateRstStream(HTTPTransaction txn,
		ref HVector buffer,HTTPErrorCode code)
	{
		return 0;
	}

	override size_t generateWsFrame(HTTPTransaction txn,
		ref HVector buffer,OpCode code, ubyte[] data)
	{
		buffer.clear();
		if((code & 0x08) == 0x08 && (data.length > 125))
				data = data[0 .. 125];
		if(code == OpCode.OpCodeClose)
			_shouldClose = true;

		int numFrames = cast(int)(data.length / FRAME_SIZE_IN_BYTES);
		auto sizeLeft = data.length % FRAME_SIZE_IN_BYTES;
		if (numFrames == 0)
			numFrames = 1;
		size_t currentPosition = 0;
		size_t bytesLeft = data.length;
		size_t bytesWritten = 0;
		const OpCode firstOpCode = code;
		for (int i = 0; i < numFrames; ++i)
		{
			
			const bool isLastFrame = (i == (numFrames - 1));
			const bool isFirstFrame = (i == 0);
			
			const OpCode opcode = isFirstFrame ? firstOpCode : OpCode.OpCodeContinue;
			
			const size_t payloadLength = bytesLeft < FRAME_SIZE_IN_BYTES ? bytesLeft
				: FRAME_SIZE_IN_BYTES;
			
			getFrameHeader(opcode, payloadLength, isLastFrame, buffer);
			if (doMask)
			{
				ubyte[4] mask = generateMaskingKey(); //TODO：生成mask
				buffer.insertBack(mask[]);
				buffer.insertBack(data);
				auto tdata = buffer.data(false);
				for (size_t j = tdata.length - payloadLength; j < tdata.length; i++)
				{
					tdata[j] ^= mask[j % 4];
				}
			}
			else
			{
				buffer.insertBack(data);
			}
			bytesLeft -= payloadLength;
			bytesWritten += payloadLength;
		}
		return buffer.length;
	}

	ubyte[4] generateMaskingKey() // Client will used
	{
		ubyte[4] code = [0, 0, 0, 0];
		return code; //TODO：生成mask
	}

protected:
	bool doMask(){return _transportDirection ==  TransportDirection.UPSTREAM;}

	void getFrameHeader(OpCode code, size_t payloadLength, bool lastFrame, ref HVector buffer)
	{
		ubyte[2] wdata = [0, 0];
		wdata[0] = cast(ubyte)((code & 0x0F) | (lastFrame ? 0x80 : 0x00));
		if(doMask())
			wdata[1] = 0x80;
		if (payloadLength <= 125){
			wdata[1] |= to!ubyte(payloadLength);
			buffer.insertBack(wdata[]);
		} else if (payloadLength <= ushort.max) {
			wdata[1] |= 126;
			buffer.insertBack(wdata[]);
			ubyte[2] length = nativeToBigEndian(to!ushort(payloadLength));
			buffer.insertBack(length[]);
		} else {
			wdata[1] |= 127;
			buffer.insertBack(wdata[]);
			auto length = nativeToBigEndian(payloadLength);
			buffer.insertBack(length[]);
		}
	}

	bool checkValidity()
	{
		void setError(CloseCode code, string closeReason)
		{
			frame._closeCode = code;
			frame._closeReason = closeReason;
			frame._isValid = false;
		}
		
		if (frame._rsv1 || frame._rsv2 || frame._rsv3)
		{
			setError(CloseCode.CloseCodeProtocolError, "Rsv field is non-zero");
		}
		else if (isOpCodeReserved(frame._opCode))
		{
			setError(CloseCode.CloseCodeProtocolError, "Used reserved opcode");
		}
		else if (frame.isControlFrame())
		{
			if (_length > 125)
			{
				setError(CloseCode.CloseCodeProtocolError, "Control frame is larger than 125 bytes");
			}
			else if (!frame._isFinalFrame)
			{
				setError(CloseCode.CloseCodeProtocolError, "Control frames cannot be fragmented");
			}
			else
			{
				frame._isValid = true;
			}
		}
		else
		{
			frame._isValid = true;
		}
		return frame._isValid;
	}

	bool isOpCodeReserved(OpCode code)
	{
		return ((code > OpCode.OpCodeBinary) && (code < OpCode.OpCodeClose))
			|| (code > OpCode.OpCodePong);
	}

	pragma(inline)
	void clear()
	{
		_state = ProcessingState.PS_READ_HEADER;
		_mask[] = 0;
		_hasMask = false;
		_buffer[] = 0;
		_readLen = 0;
		frame = WSFrame();
	}

	void readFrame(in ubyte[] data)
	{
		
		void resultOne()
		{
			if (frame.isValid && frame.isDataFrame())
			{
				if (!frame.isContinuationFrame())
				{
					_lastcode = frame.opCode();
				} 
				frame._lastCode = _lastcode;
				if (_hasMask)
				{ //解析mask
					for (size_t i = 0; i < _length; ++i)
					{
						frame.data[i] = frame.data[i] ^ _mask[i % 4];
					}
				}
			}
			if(_callback)
				_callback.onWsFrame(_transaction,frame);
			clear();
		}
		
		const size_t len = data.length;
		for (size_t i = 0; i < len; ++i)
		{
			ubyte ch = data[i];
			final switch (_state)
			{
				case ProcessingState.PS_READ_HEADER:
					frame._isFinalFrame = (ch & 0x80) != 0;
					frame._rsv1 = ((ch & 0x40) != 0);
					frame._rsv2 = ((ch & 0x20) != 0);
					frame._rsv3 = ((ch & 0x10) != 0);
					frame._opCode = cast(OpCode)(ch & 0x0F);
					_state = ProcessingState.PS_READ_Do_LENGTH;
					break;
				case ProcessingState.PS_READ_Do_LENGTH:
				{
					_hasMask = (ch & 0x80) != 0;
					auto tlen = (ch & 0x7F);
					switch (tlen)
					{
						case 126:
						{
							_state = ProcessingState.PS_READ_PAYLOAD_LENGTH;
							break;
						}
						case 127:
						{
							_state = ProcessingState.PS_READ_BIG_PAYLOAD_LENGTH;
							break;
						}
						default:
						{
							_length = tlen;
							frame.data = new ubyte[_length];
							_state = _hasMask ? ProcessingState.PS_READ_MASK
								: ProcessingState.PS_READ_PAYLOAD;
							break;
						}
					}
					if (!checkValidity())
					{
						_state = ProcessingState.PS_READ_HEADER;
						resultOne();
					}
				}
					break;
				case ProcessingState.PS_READ_PAYLOAD_LENGTH:
				{
					if (len - i >= 2)
					{
						ubyte[2] tlen = data[i .. (i + 2)];
						++i;
						_length = bigEndianToNative!(ushort)(tlen);
						frame.data = new ubyte[_length];
						_state = _hasMask ? ProcessingState.PS_READ_MASK
							: ProcessingState.PS_READ_PAYLOAD;
					}
					else
					{
						_buffer[] = 0;
						_buffer[0] = ch;
						_state = ProcessingState.PS_READ_PAYLOAD_LENGTH_1;
					}
				}
					break;
				case ProcessingState.PS_READ_PAYLOAD_LENGTH_1:
				{
					_buffer[1] = ch;
					ubyte[2] tlen = _buffer[0 .. 2];
					_length = bigEndianToNative!ushort(tlen);
					frame.data = new ubyte[_length];
					_state = _hasMask ? ProcessingState.PS_READ_MASK
						: ProcessingState.PS_READ_PAYLOAD;
				}
					break;
				case ProcessingState.PS_READ_BIG_PAYLOAD_LENGTH:
					auto llen = len - i;
					if (llen >= 8)
					{
						ubyte[8] tlen = data[i .. (i + 8)];
						i += 7;
						_length = cast(size_t) bigEndianToNative!ulong(tlen);
						frame.data = new ubyte[_length];
						_state = _hasMask ? ProcessingState.PS_READ_MASK
							: ProcessingState.PS_READ_PAYLOAD;
						_readLen = 0;
					}
					else
					{
						_buffer[] = 0;
						_buffer[0 .. llen] = data[i .. $];
						_readLen = llen;
						i += llen;
						_state = ProcessingState.PS_READ_BIG_PAYLOAD_LENGTH_1;
					}
					break;
				case ProcessingState.PS_READ_BIG_PAYLOAD_LENGTH_1:
				{
					auto llen = len - i;
					auto rlen = 8 - _readLen;
					if (llen >= rlen)
					{
						_buffer[_readLen .. 8] = data[i .. (i + rlen)];
						i += rlen;
						--i;
						_length = cast(size_t) bigEndianToNative!ulong(_buffer);
						frame.data = new ubyte[_length];
						_state = _hasMask ? ProcessingState.PS_READ_MASK
							: ProcessingState.PS_READ_PAYLOAD;
						_readLen = 0;
					}
					else
					{
						_buffer[_readLen .. (_readLen + llen)] = data[i .. $];
						_readLen += llen;
						i += llen;
						_state = ProcessingState.PS_READ_BIG_PAYLOAD_LENGTH_1;
					}
				}
					break;
				case ProcessingState.PS_READ_MASK:
					auto llen = len - i;
					if (llen >= 4)
					{
						const ubyte[] tlen = data[i .. (i + 4)];
						i += 3;
						_mask[] = tlen[];
						_state = ProcessingState.PS_READ_PAYLOAD;
						_readLen = 0;
					}
					else
					{
						_mask[] = 0;
						_mask[0 .. llen] = data[i .. $];
						_readLen = llen;
						i += llen;
						_state = ProcessingState.PS_READ_MASK_1;
					}
					break;
				case ProcessingState.PS_READ_MASK_1:
				{
					auto llen = len - i;
					auto rlen = 4 - _readLen;
					if (llen >= rlen)
					{
						_mask[_readLen .. 4] = data[i .. (i + rlen)];
						i += rlen;
						--i;
						_state = ProcessingState.PS_READ_PAYLOAD;
						_readLen = 0;
					}
					else
					{
						_mask[_readLen .. (_readLen + llen)] = data[i .. $];
						_readLen += llen;
						i += llen;
						_state = ProcessingState.PS_READ_MASK_1;
					}
				}
					break;
				case ProcessingState.PS_READ_PAYLOAD:
				{
					trace("\n\t_length = ", _length);
					auto llen = len - i;
					auto rlen = _length - _readLen;
					if (llen >= rlen)
					{
						frame.data[_readLen .. (_readLen + rlen)] = data[i .. (i + rlen)];
						i += rlen;
						--i;
						_state = ProcessingState.PS_READ_HEADER;
						resultOne();
					}
					else
					{
						frame.data[_readLen .. (_readLen + llen)] = data[i .. $];
						_readLen += llen;
					}
				}
					break;
					
			}
		}
	}

private:
	TransportDirection _transportDirection;
	bool _finished;
	bool _shouldClose = false;
	CallBack _callback;
	HTTPTransaction _transaction;

	ProcessingState _state;
	OpCode _lastcode;
	WSFrame frame;
	bool _hasMask;
	ubyte[4] _mask;
	ubyte[8] _buffer;
	size_t _length;
	size_t _readLen;
}

