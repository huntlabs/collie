module collie.codec.http.codec.httpcodec;

import collie.codec.http.httpmessage;
import collie.codec.http.errocode;

class HTTPCodec
{

	/**
   * Key that uniquely identifies a request/response pair within
   * (and only within) the scope of the codec.  Code outside the
   * codec should regard the StreamID as an opaque data
   * structure; different subclasses of HTTPCodec are likely to
   * use different conventions for generating StreamID values.
   *
   * A value of zero indicates an uninitialized/unknown/unspecified
   * StreamID.
   */
	typedef StreamID = uint;

	this()
	{}

	interface CallBack
	{
		/**
     * Called when a new message is seen while parsing the ingress
     * @param stream   The stream ID
     * @param msg      A newly allocated HTTPMessage
     */
	 void onMessageBegin(StreamID stream, HTTPMessage* msg);
		
		/**
     * Called when a new push message is seen while parsing the ingress.
     *
     * @param stream   The stream ID
     * @param assocStream The stream ID of the associated stream,
     *                 which can never be 0
     * @param msg      A newly allocated HTTPMessage
     */
	void onPushMessageBegin(StreamID stream,
		StreamID assocStream,
			HTTPMessage* msg);
		
		/**
     * Called when all the headers of an ingress message have been parsed
     * @param stream   The stream ID
     * @param msg      The message
     * @param size     Size of the ingress header
     */
	void onHeadersComplete(StreamID stream,
		HTTPMessage* msg);
		
		/**
     * Called for each block of message body data
     * @param stream  The stream ID
     * @param chain   One or more buffers of body data. The codec will
     *                remove any protocol framing, such as HTTP/1.1 chunk
     *                headers, from the buffers before calling this function.
     * @param padding Number of pad bytes that came with the data segment
     */
		void onBody(StreamID stream,const ubyte[] data);
		
		/**
     * Called for each HTTP chunk header.
     *
     * onChunkHeader() will be called when the chunk header is received.  As
     * the chunk data arrives, it will be passed to the callback normally with
     * onBody() calls.  Note that the chunk data may arrive in multiple
     * onBody() calls: it is not guaranteed to arrive in a single onBody()
     * call.
     *
     * After the chunk data has been received and the terminating CRLF has been
     * received, onChunkComplete() will be called.
     *
     * @param stream    The stream ID
     * @param length    The chunk length.
     */
		void onChunkHeader(StreamID stream, size_t length);
		
		/**
     * Called when the terminating CRLF is received to end a chunk of HTTP body
     * data.
     *
     * @param stream    The stream ID
     */
		void onChunkComplete(StreamID stream);
		
		/**
     * Called at end of a message (including body and trailers, if applicable)
     * @param stream   The stream ID
     * @param upgrade  Whether the connection has been upgraded to another
     *                 protocol.
     */
		void onMessageComplete(StreamID stream, bool upgrade);
		
		/**
     * Called when a parsing or protocol error has occurred
     * @param stream   The stream ID
     * @param error    Description of the error
     * @param newTxn   true if onMessageBegin has not been called for txn
     */
		void onError(StreamID stream,string erromsg);
		
		/**
     * Called when the peer has asked to shut down a stream
     * immediately.
     * @param stream   The stream ID
     * @param code     The code the stream was aborted with
     * @note  Not applicable to all protocols.
     */
		void onAbort(StreamID stream,
			HTTPErrorCode code);
		
		/**
     * Called upon receipt of a frame header.
     * @param stream_id The stream ID
     * @param flags     The flags field of frame header
     * @param length    The length field of frame header
     * @param version   The version of frame (SPDY only)
     * @note Not all protocols have frames. SPDY does, but HTTP/1.1 doesn't.
     */
//		void onFrameHeader(uint stream_id,
//			ubyte flags,
//			uint length,
//			ushort version_ = 0);
		
		/**
     * Called upon receipt of a goaway.
     * @param lastGoodStreamID  Last successful stream created by the receiver
     * @param code              The code the connection was aborted with
     * @param debugData         The additional debug data for diagnostic purpose
     * @note Not all protocols have goaways. SPDY does, but HTTP/1.1 doesn't.
     */
//		void onGoaway(ulong lastGoodStreamID,
//			HTTPErrorCode code,
//			const ubyte[] debugData = null);

		/**
     * Called upon receipt of a ping request
     * @param uniqueID  Unique identifier for the ping
     * @note Not all protocols have pings.  SPDY does, but HTTP/1.1 doesn't.
     */
//		void onPingRequest(ulong uniqueID);
		
		/**
     * Called upon receipt of a ping reply
     * @param uniqueID  Unique identifier for the ping
     * @note Not all protocols have pings.  SPDY does, but HTTP/1.1 doesn't.
     */
//		void onPingReply(ulong uniqueID);
		
		/**
     * Called upon receipt of a window update, for protocols that support
     * flow control. For instance spdy/3 and higher.
     */
//		void onWindowUpdate(StreamID stream, uint amount);
		
		/**
     * Called upon receipt of a settings frame, for protocols that support
     * settings.
     *
     * @param settings a list of settings that were sent in the settings frame
     */
		//void onSettings(const SettingsList& settings);
		
		/**
     * Called upon receipt of a settings frame with ACK set, for
     * protocols that support settings ack.
     */
//		void onSettingsAck();
		
		/**
     * Called upon receipt of a priority frame, for protocols that support
     * dynamic priority
     */
//		void onPriority(StreamID stream,
//			const HTTPMessage::HTTPPriority& pri);
		
		/**
     * Called upon receipt of a valid protocol switch.  Return false if
     * protocol switch could not be completed.
     */
//		bool onNativeProtocolUpgrade(StreamID stream,
//			CodecProtocol protocol,
//			const std::string& protocolString,
//			HTTPMessage& msg) {
//			return false;
//		}
		
		/**
     * Return the number of open streams started by this codec callback.
     * Parallel codecs with a maximum number of streams will invoke this
     * to determine if a new stream exceeds the limit.
     */
		//uint32_t numOutgoingStreams() const { return 0; }
		
		/**
     * Return the number of open streams started by the remote side.
     * Parallel codecs with a maximum number of streams will invoke this
     * to determine if a new stream exceeds the limit.
     */
		//uint32_t numIncomingStreams() const { return 0; }

	}

	
}

