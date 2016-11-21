module collie.codec.http.codec.wsframe;

enum WebSocketGuid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

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
/**
 * websocket frame
*/
struct WSFrame
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

	@property parentCode()
	{
		return _lastCode;
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

package (collie.codec.http.codec):  
	
	bool _isFinalFrame;
	bool _rsv1;
	bool _rsv2;
	bool _rsv3;
	bool _isValid = false;
	OpCode _opCode;
	OpCode _lastCode;
	string _closeReason;
	CloseCode _closeCode;
}
