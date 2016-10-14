module collie.codec.http.errocode;

enum HTTPErrorCode {
	NO_ERROR = 0,
		PROTOCOL_ERROR = 1,
		INTERNAL_ERROR = 2,
		FLOW_CONTROL_ERROR = 3,
		SETTINGS_TIMEOUT = 4,
		STREAM_CLOSED = 5,
		FRAME_SIZE_ERROR = 6,
		REFUSED_STREAM = 7,
		CANCEL = 8,
		COMPRESSION_ERROR = 9,
		CONNECT_ERROR = 10,
		ENHANCE_YOUR_CALM = 11,
		INADEQUATE_SECURITY = 12,
		HTTP_1_1_REQUIRED = 13,
		// This code is *NOT* to be used outside of SPDYCodec. Delete this
		// when we deprecate SPDY.
		_SPDY_INVALID_STREAM = 100,
}
