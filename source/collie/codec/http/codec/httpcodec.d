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
module collie.codec.http.codec.httpcodec;

import collie.codec.http.httpmessage;
import collie.codec.http.errocode;
import collie.codec.http.codec.wsframe;
import collie.codec.http.httptansaction;
import collie.utils.vector;

import std.experimental.allocator.gc_allocator;

enum CodecProtocol : ubyte {
	init = 0,
	HTTP_1_X = 1,
	WEBSOCKET = 2,
//	SPDY_3,
//	SPDY_3_1,
//	SPDY_3_1_HPACK,
	HTTP_2 = 3
};

abstract class HTTPCodec
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
	alias StreamID = uint;
	alias HVector = Vector!(ubyte);

	this()
	{}

	interface CallBack
	{
		/**
     * Called when a new message is seen while parsing the ingress
     * @param stream   The stream ID
     * @param msg      A newly allocated HTTPMessage
     */
	 void onMessageBegin(HTTPTransaction txn, HTTPMessage msg);
		
		/**
     * Called when a new push message is seen while parsing the ingress.
     *
     * @param stream   The stream ID
     * @param assocStream The stream ID of the associated stream,
     *                 which can never be 0
     * @param msg      A newly allocated HTTPMessage
     */
//	void onPushMessageBegin(HTTPTransaction txn,
//		StreamID assocStream,
//			HTTPMessage* msg);
//		
		/**
     * Called when all the headers of an ingress message have been parsed
     * @param stream   The stream ID
     * @param msg      The message
     * @param size     Size of the ingress header
     */
	void onHeadersComplete(HTTPTransaction txn,
		HTTPMessage msg);
		
		/**
     * Called for each block of message body data
     * @param stream  The stream ID
     * @param chain   One or more buffers of body data. The codec will
     *                remove any protocol framing, such as HTTP/1.1 chunk
     *                headers, from the buffers before calling this function.
     * @param padding Number of pad bytes that came with the data segment
     */
		void onBody(HTTPTransaction txn,const ubyte[] data);
		
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
		void onChunkHeader(HTTPTransaction txn, size_t length);
		
		/**
     * Called when the terminating CRLF is received to end a chunk of HTTP body
     * data.
     *
     * @param stream    The stream ID
     */
		void onChunkComplete(HTTPTransaction txn);
		
		/**
     * Called at end of a message (including body and trailers, if applicable)
     * @param stream   The stream ID
     * @param upgrade  Whether the connection has been upgraded to another
     *                 protocol.
     */
		void onMessageComplete(HTTPTransaction txn, bool upgrade);
		
		/**
     * Called when a parsing or protocol error has occurred
     * @param stream   The stream ID
     * @param error    Description of the error
     * @param newTxn   true if onMessageBegin has not been called for txn
     */
		void onError(HTTPTransaction txn,HTTPErrorCode);
		
		/**
     * Called when the peer has asked to shut down a stream
     * immediately.
     * @param stream   The stream ID
     * @param code     The code the stream was aborted with
     * @note  Not applicable to all protocols.
     */
		void onAbort(HTTPTransaction txn,
			HTTPErrorCode code);

		void onWsFrame(HTTPTransaction ,ref WSFrame);
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
//		void onWindowUpdate(HTTPTransaction txn, uint amount);
		
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
//		void onPriority(HTTPTransaction txn,
//			const HTTPMessage::HTTPPriority& pri);
		
		/**
     * Called upon receipt of a valid protocol switch.  Return false if
     * protocol switch could not be completed.
     */
		void onNativeProtocolUpgrade(HTTPTransaction txn,
			CodecProtocol protocol,
			string protocolString,
			HTTPMessage msg);
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

	CodecProtocol getProtocol();

	StreamID createStream();
	/**
   * Get the transport direction of this codec:
   * DOWNSTREAM if the codec receives requests from clients or
   * UPSTREAM if the codec sends requests to servers.
   */
	TransportDirection getTransportDirection();
	
	/**
   * Returns true iff this codec supports per stream flow control
   */
	bool supportsStreamFlowControl() const {
		return false;
	}
	
	/**
   * Returns true iff this codec supports session level flow control
   */
	bool supportsSessionFlowControl() const {
		return false;
	}
	
	/**
   * Set the callback to notify on ingress events
   * @param callback  The callback object
   */
	void setCallback(CallBack callback);
	
	/**
   * Check whether the codec still has at least one HTTP
   * stream to parse.
   */
	bool isBusy();

	bool shouldClose();
	
	/**
   * Pause or resume the ingress parser
   * @param paused  Whether the caller wants the parser to be paused
   */
	void setParserPaused(bool paused);
	
	/**
   * Parse ingress data.
   * @param  buf   A single IOBuf of data to parse
   * @return Number of bytes consumed.
   */
	size_t onIngress(ubyte[] buf);

	void onConnectClose();

	void onTimeOut();

	void detach(HTTPTransaction txn);
	/**
   * Finish parsing when the ingress stream has ended.
   */

	//void onIngressEOF();
	
/**
   * Invoked on a codec that has been upgraded to via an HTTPMessage on
   * a different codec.  The codec may return false to halt the upgrade.
   */
//	bool onIngressUpgradeMessage(const HTTPMessage msg) {
//		return true;
//	}
	
	/**
   * Check whether the codec can process new streams. Typically,
   * an implementing subclass will return true when a new codec is
   * created and false once it encounters a situation that would
   * prevent reuse of the underlying transport (e.g., a "Connection: close"
   * in HTTP/1.x).
   * @note A return value of true means that the codec can process new
   *       connections at some reasonable point in the future; that may
   *       mean "immediately," for codecs that support pipelined or
   *       interleaved requests, or "upon completion of the current
   *       stream" for codecs that do not.
   */
//	bool isReusable();
	
	/**
   * Returns true if this codec is in a state where it accepting new
   * requests but will soon begin to reject new requests. For SPDY and
   * HTTP/2, this is true when the first GOAWAY NO_ERROR is sent during
   * graceful shutdown.
   */
//	bool isWaitingToDrain();
	
	/**
   * Checks whether the socket needs to be closed when EOM is sent. This is used
   * during CONNECT when EOF needs to be sent after upgrade to notify the server
   */
//	bool closeOnEgressComplete();
	
	/**
   * Check whether the codec supports the processing of multiple
   * requests in parallel.
   */
//	bool supportsParallelRequests();
	
	/**
   * Check whether the codec supports pushing resources from server to
   * client.
   */
//	bool supportsPushTransactions();
	
	/**
   * Write an egress message header.  For pushed streams, you must specify
   * the assocStream.
   * @retval size the size of the generated message, both the actual size
   *              and the size of the uncompressed data.
   * @return None
   */
	size_t generateHeader(
		HTTPTransaction txn,
		HTTPMessage msg,
		ref HVector buffer,
		bool eom = false);
		//HTTPHeaderSize* size = nullptr);
	
	/**
   * Write part of an egress message body.
   *
   * This will automatically generate a chunk header and footer around the data
   * if necessary (e.g. you haven't manually sent a chunk header and the
   * message should be chunked).
   *
   * @param padding Optionally add padding bytes to the body if possible
   * @param eom implicitly generate the EOM marker with this body frame
   *
   * @return number of bytes written
   */
	size_t generateBody(HTTPTransaction txn,
		ref HVector chain,
		bool eom);

	/**
   * Write a body chunk header, if relevant.
   */
	size_t generateChunkHeader(
		HTTPTransaction txn,
		ref HVector buffer,
		size_t length);
	
	/**
   * Write a body chunk terminator, if relevant.
   */
	size_t generateChunkTerminator(
		HTTPTransaction txn,
		ref HVector buffer);

	/**
   * Generate any protocol framing needed to finalize an egress
   * message. This method must be called to complete a stream.
   *
   * @return number of bytes written
   */
	size_t generateEOM(HTTPTransaction txn,
		ref HVector buffer);
	
	/**
   * Generate any protocol framing needed to abort a connection.
   * @return number of bytes written
   */
	size_t generateRstStream(HTTPTransaction txn,
		ref HVector buffer,HTTPErrorCode code);


	size_t generateWsFrame(HTTPTransaction txn,
		ref HVector buffer,OpCode code, ubyte[] data)
	{
		return 0;
	}

	static CodecProtocol getProtocolFormString(string str)
	{
		import collie.utils.string;
		if(isSameIngnoreLowUp(str,"websocket")){
			return CodecProtocol.WEBSOCKET;
		} else if(isSameIngnoreLowUp(str,"H2C")){
			return CodecProtocol.HTTP_2;
		}
		return CodecProtocol.init;
		/*
		switch(str){

			case "websocket" : 
				return CodecProtocol.WEBSOCKET;
			case "H2C" :
				return CodecProtocol.HTTP_2;
			default:
				return CodecProtocol.init;
		}*/
	}
}

