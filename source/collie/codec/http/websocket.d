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
module collie.codec.http.websocket;

import std.conv;
import std.socket;
import std.bitmanip;
import std.experimental.logger;

import collie.buffer.buffer;
//import collie.codec.http.handler;

enum WebSocketGuid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

//abstract class WebSocket
//{
//    pragma(inline)
//    final bool ping(ubyte[] data)
//    {
//        if (_hand)
//            return _hand.ping(data);
//        else
//            return false;
//    }
//
//    pragma(inline)
//    final bool sendText(string text)
//    {
//        if (_hand)
//        {
//            return _hand.send(cast(ubyte[]) text, false);
//        }
//        else
//        {
//            return false;
//        }
//    }
//
//    pragma(inline)
//    final bool sendBinary(ubyte[] data)
//    {
//        if (_hand)
//            return _hand.send(data, true);
//        else
//            return false;
//    }
//
//    pragma(inline,true)
//    final void close()
//    {
//        if (_hand)
//            _hand.doClose();
//    }
//
//    pragma(inline,true)
//    final @property Address remoteAdress()
//    {
//        return _addr;
//    }
//
//    void onClose();
//    void onTextFrame(Frame frame);
//    void onPongFrame(Frame frame);
//    void onBinaryFrame(Frame frame);
//
//package:
//    Object _hand;
//    Address _addr;
//}

enum FRAME_SIZE_IN_BYTES = 512 * 512 * 2; //maximum size of a frame when sending a message

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

enum OpCode
{
    OpCodeContinue = 0x0,
    OpCodeText = 0x1,
    OpCodeBinary = 0x2,
    OpCodeReserved3 = 0x3,
    OpCodeReserved4 = 0x4,
    OpCodeReserved5 = 0x5,
    OpCodeReserved6 = 0x6,
    OpCodeReserved7 = 0x7,
    OpCodeClose = 0x8,
    OpCodePing = 0x9,
    OpCodePong = 0xA,
    OpCodeReservedB = 0xB,
    OpCodeReservedC = 0xC,
    OpCodeReservedD = 0xD,
    OpCodeReservedE = 0xE,
    OpCodeReservedF = 0xF
}

enum CloseCode
{
    CloseCodeNormal = 1000,
    CloseCodeGoingAway = 1001,
    CloseCodeProtocolError = 1002,
    CloseCodeDatatypeNotSupported = 1003,
    CloseCodeReserved1004 = 1004,
    CloseCodeMissingStatusCode = 1005,
    CloseCodeAbnormalDisconnection = 1006,
    CloseCodeWrongDatatype = 1007,
    CloseCodePolicyViolated = 1008,
    CloseCodeTooMuchData = 1009,
    CloseCodeMissingExtension = 1010,
    CloseCodeBadOperation = 1011,
    CloseCodeTlsHandshakeFailed = 1015
}

final class Frame
{

    bool isControlFrame() const
    {
        return (_opCode & 0x08) == 0x08;
    }

    bool isDataFrame() const
    {
        return !isControlFrame();
    }

    bool isContinuationFrame() const
    {
        return isDataFrame() && (opCode == OpCode.OpCodeContinue);
    }

    @property opCode() const
    {
        return _opCode;
    }

    @property isFinalFrame() const
    {
        return _isFinalFrame;
    }

    @property closeCode() const
    {
        return _closeCode;
    }

    @property closeReason()
    {
        return _closeReason;
    }

    @property rsv1() const
    {
        return _rsv1;
    }

    @property rsv2() const
    {
        return _rsv2;
    }

    @property rsv3() const
    {
        return _rsv3;
    }

    @property isValid() const
    {
        return _isValid;
    }

    ubyte[] data;
private:

    bool _isFinalFrame;
    bool _rsv1;
    bool _rsv2;
    bool _rsv3;
    bool _isValid = false;
    OpCode _opCode;
    string _closeReason;
    CloseCode _closeCode;
}

final class HandleFrame
{

    this(bool mask)
    {
        clear();
        doMask = mask;
    }

    pragma(inline,true)
    void clear()
    {
        _state = ProcessingState.PS_READ_HEADER;
        _mask[] = 0;
        _hasMask = false;
        _buffer[] = 0;
        _readLen = 0;
        frame = new Frame();
    }

    void ping(ubyte[] data, Buffer buffer)
    {
        if (data.length > 125)
        {
            data = data[0 .. 125];
        }
        getFrameHeader(OpCode.OpCodePing, data.length, true, buffer);
        if (doMask)
        {
            ubyte[4] mask = generateMaskingKey();
            buffer.write(mask);
            buffer.write(data);
            buffer.rest(buffer.length - data.length);
            buffer.read(data.length, delegate(in ubyte[] data) {
                auto tdata = cast(ubyte[]) data; //强转去掉const属性
                for (size_t i = 0; i < tdata.length; i++)
                {
                    tdata[i] ^= mask[i % 4];
                }
            });

        }
        else
        {
            buffer.write(data);
        }
    }

    void pong(ubyte[] data, Buffer buffer)
    {
        if (data.length > 125)
        {
            data = data[0 .. 125];
        }
        getFrameHeader(OpCode.OpCodePong, data.length, true, buffer);
        if (doMask)
        {
            ubyte[4] mask = generateMaskingKey();
            buffer.write(mask);
            buffer.write(data);
            buffer.rest(buffer.length - data.length);
            buffer.read(data.length, delegate(in ubyte[] data) {
                auto tdata = cast(ubyte[]) data; //强转去掉const属性
                for (size_t i = 0; i < tdata.length; i++)
                {
                    tdata[i] ^= mask[i % 4];
                }
            });

        }
        else
        {
            buffer.write(data);
        }
    }

    void writeFrame(ubyte[] data, bool isBinary, Buffer buffer)
    {
        const OpCode firstOpCode = isBinary ? OpCode.OpCodeBinary : OpCode.OpCodeText;

        int numFrames = cast(int)(data.length / FRAME_SIZE_IN_BYTES);

        auto sizeLeft = data.length % FRAME_SIZE_IN_BYTES;
        if (sizeLeft > 0)
            ++numFrames;

        //catch the case where the payload is zero bytes;
        //in this case, we still need to send a frame
        if (numFrames == 0)
            numFrames = 1;
        size_t currentPosition = 0;
        size_t bytesLeft = data.length;
        size_t bytesWritten = 0;

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
                buffer.write(mask);
                buffer.write(data);
                buffer.rest(buffer.length - payloadLength);
                buffer.read(payloadLength, delegate(in ubyte[] data) {
                    auto tdata = cast(ubyte[]) data; //强转去掉const属性
                    for (size_t i = 0; i < tdata.length; i++)
                    {
                        tdata[i] ^= mask[i % 4];
                    }
                });

            }
            else
            {
                buffer.write(data);
            }
            bytesLeft -= payloadLength;
            bytesWritten += payloadLength;
        }

        return;
    }

    void readFrame(in ubyte[] data, void delegate(Frame frame, bool text) callback)
    {

        void resultOne()
        {
            bool text = false;
            if (frame.isValid && frame.isDataFrame())
            {
                if (!frame.isContinuationFrame())
                {
                    _lastcode = frame.opCode();
                }
                text = (_lastcode == OpCode.OpCodeText);
                if (_hasMask)
                { //解析mask
                    for (size_t i = 0; i < _length; ++i)
                    {
                        frame.data[i] = frame.data[i] ^ _mask[i % 4];
                    }
                }
            }

            callback(frame, text);
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

protected:

    void getFrameHeader(OpCode opCode, ulong payloadLength, bool lastFrame, Buffer buffer)
    {
        ubyte[2] wdata = [0, 0];

        wdata[0] = cast(ubyte)((opCode & 0x0F) | (lastFrame ? 0x80 : 0x00));
        if (doMask)
        {
            wdata[1] = 0x80;
        }
        if (payloadLength <= 125)
        {
            wdata[1] |= to!ubyte(payloadLength);
            buffer.write(wdata);
        }
        else if (payloadLength <= ushort.max)
        {
            wdata[1] |= 126;
            buffer.write(wdata);
            ubyte[2] length = nativeToBigEndian(to!ushort(payloadLength));
            buffer.write(length);

        }
        else
        {
            wdata[1] |= 127;
            buffer.write(wdata);
            ubyte[8] length = nativeToBigEndian(payloadLength);
            buffer.write(length);
        }
    }

    bool isOpCodeReserved(OpCode code)
    {
        return ((code > OpCode.OpCodeBinary) && (code < OpCode.OpCodeClose))
            || (code > OpCode.OpCodePong);
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

    ubyte[4] generateMaskingKey() // Client will used
    {
        ubyte[4] code = [0, 0, 0, 0];
        return code; //TODO：生成mask
    }

private:
    ProcessingState _state;
    OpCode _lastcode;
    ubyte[4] _mask;
    bool _hasMask;
    ubyte[8] _buffer;
    size_t _length;
    size_t _readLen;
    Frame frame;
    bool doMask = false;
}
