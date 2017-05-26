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
module collie.codec.http.httptansaction;

import collie.codec.http.codec.httpcodec;
import collie.codec.http.httpmessage;
import collie.codec.http.errocode;
import collie.socket.tcpsocket;

import std.socket;
public import std.experimental.logger;
import collie.codec.http.codec.wsframe;

enum TransportDirection : ubyte {
	DOWNSTREAM,  // toward the client
	UPSTREAM     // toward the origin application or data
}

interface HTTPTransactionHandler 
{
	/**
   * Called once per transaction. This notifies the handler of which
   * transaction it should talk to and will receive callbacks from.
   */
	void setTransaction(HTTPTransaction txn);
	/**
   * Called once after a transaction successfully completes. It
   * will be called even if a read or write error happened earlier.
   * This is a terminal callback, which means that the HTTPTransaction
   * object that gives this call will be invalid after this function
   * completes.
   */
	void detachTransaction();
	
	/**
   * Called at most once per transaction. This is usually the first
   * ingress callback. It is possible to get a read error before this
   * however. If you had previously called pauseIngress(), this callback
   * will be delayed until you call resumeIngress().
   */
	void onHeadersComplete(HTTPMessage msg);
	
	/**
   * Can be called multiple times per transaction. If you had previously
   * called pauseIngress(), this callback will be delayed until you call
   * resumeIngress().
   */
	void onBody(const ubyte[] chain);
	
	/**
   * Can be called multiple times per transaction. If you had previously
   * called pauseIngress(), this callback will be delayed until you call
   * resumeIngress(). This signifies the beginning of a chunk of length
   * 'length'. You will receive onBody() after this. Also, the length will
   * be greater than zero.
   */
	void onChunkHeader(size_t length) ;
	
	/**
   * Can be called multiple times per transaction. If you had previously
   * called pauseIngress(), this callback will be delayed until you call
   * resumeIngress(). This signifies the end of a chunk.
   */
	void onChunkComplete() ;
	
	/**
   * Can be called any number of times per transaction. If you had
   * previously called pauseIngress(), this callback will be delayed until
   * you call resumeIngress(). Trailers can be received once right before
   * the EOM of a chunked HTTP/1.1 reponse or multiple times per
   * transaction from SPDY and HTTP/2.0 HEADERS frames.
   */
//	void onTrailers(std::unique_ptr<HTTPHeaders> trailers) noexcept
//		= 0;
	
	/**
   * Can be called once per transaction. If you had previously called
   * pauseIngress(), this callback will be delayed until you call
   * resumeIngress(). After this callback is received, there will be no
   * more normal ingress callbacks received (onEgress*() and onError()
   * may still be invoked). The Handler should consider
   * ingress complete after receiving this message. This Transaction is
   * still valid, and work may still occur on it until detachTransaction
   * is called.
   */
	void onEOM();
	
	/**
   * Can be called at any time before detachTransaction(). This callback
   * implies that an error has occurred. To determine if ingress or egress
   * is affected, check the direciont on the HTTPException. If the
   * direction is INGRESS, it MAY still be possible to send egress.
   */
	void onError(HTTPErrorCode erromsg);
	
	/**
   * If the remote side's receive buffer fills up, this callback will be
   * invoked so you can attempt to stop sending to the remote side.
   */
	void onEgressPaused();
	
	/**
   * This callback lets you know that the remote side has resumed reading
   * and you can now continue to send data.
   */
	void onEgressResumed();

	void onWsFrame(ref WSFrame wsf);


	bool onUpgtade(CodecProtocol protocol,HTTPMessage msg);
}

class HTTPTransaction
{
	alias HVector = HTTPCodec.HVector;
	interface Transport
	{
		alias SocketWriteCallBack = TCPWriteCallBack;

		void pauseIngress(HTTPTransaction txn);
		
		void resumeIngress(HTTPTransaction txn);
		
		void transactionTimeout(HTTPTransaction txn);
		
		void sendHeaders(HTTPTransaction txn,
			HTTPMessage headers,
			bool eom);
		
		size_t sendBody(HTTPTransaction txn,
			ubyte[],
			bool eom);
		size_t sendBody(HTTPTransaction txn,
			ref HVector,
			bool eom);
		
		size_t sendChunkHeader(HTTPTransaction txn,
			size_t length);
		
		size_t sendChunkTerminator(HTTPTransaction txn);

		
		size_t sendEOM(HTTPTransaction txn);

		void socketWrite(HTTPTransaction txn,ubyte[] data,SocketWriteCallBack cback);

//		size_t sendAbort(HTTPTransaction txn,
//			HTTPErrorCode statusCode);

		size_t sendWsData(HTTPTransaction txn,OpCode code,ubyte[] data);
//		size_t sendPriority(HTTPTransaction txn,
//			const http2::PriorityUpdate& pri);
//		
//		size_t sendWindowUpdate(HTTPTransaction txn,
//			uint32_t bytes);
		
		void notifyPendingEgress();
		
		void detach(HTTPTransaction txn);
		
//		void notifyIngressBodyProcessed(uint32_t bytes);
//		
//		void notifyEgressBodyBuffered(int64_t bytes);
		
		Address getLocalAddress();
		
		Address getPeerAddress();

		
		HTTPCodec getCodec();
		
		bool isDraining();

	}

	this(TransportDirection direction, HTTPCodec.StreamID id,uint seqNo)
	{
		_id = id;
		_seqNo = seqNo;
	}
	@property HTTPTransactionHandler handler(){return _handler;}
	@property void handler(HTTPTransactionHandler han){_handler = han;}

	@property streamID(){return _id;}
	@property transport(Transport port){_transport = port;}
	@property transport(){return _transport;}

	bool isUpstream() const {
		return _direction == TransportDirection.UPSTREAM;
	}
	
	bool isDownstream() const {
		return _direction == TransportDirection.DOWNSTREAM;
	}
	uint getSequenceNumber() const { return _seqNo; }

	HTTPCodec.StreamID getID() const { return _id; }


	Address getLocalAddress(){return _transport.getLocalAddress();}
	
	Address getPeerAddress(){return _transport.getPeerAddress();}

	/**
   * Invoked by the session when the ingress headers are complete
   */
	void onIngressHeadersComplete(HTTPMessage msg)
	{
		trace("onIngressHeadersComplete handle is ", (handler is null));
		if(isUpstream() && msg.isResponse()) {
			_lastResponseStatus = msg.statusCode;
		}
		if(_handler)
			_handler.onHeadersComplete(msg);
	}
	
	/**
   * Invoked by the session when some or all of the ingress entity-body has
   * been parsed.
   */
	void onIngressBody(const ubyte[] chain, ushort padding)
	{
		if(_handler)
			_handler.onBody(chain);
	}
	
	/**
   * Invoked by the session when a chunk header has been parsed.
   */
	void onIngressChunkHeader(size_t length)
	{
		if(_handler)
			_handler.onChunkHeader(length);
	}
	
	/**
   * Invoked by the session when the CRLF terminating a chunk has been parsed.
   */
	void onIngressChunkComplete()
	{
		if(_handler)
			_handler.onChunkComplete();
	}

	/**
   * Invoked by the session when the ingress message is complete.
   */
	void onIngressEOM()
	{
		if(_handler)
			_handler.onEOM();
	}

	void onErro(HTTPErrorCode erro)
	{
		if(_handler)
			_handler.onError(erro);
	}
	/**
   * Schedule or refresh the timeout for this transaction
   */
	void refreshTimeout() {}

	/**
   * Timeout callback for this transaction.  The timer is active while
   * until the ingress message is complete or terminated by error.
   */
	void timeoutExpired() {}

	/**
   * Send the egress message headers to the Transport. This method does
   * not actually write the message out on the wire immediately. All
   * writes happen at the end of the event loop at the earliest.
   * Note: This method should be called once per message unless the first
   * headers sent indicate a 1xx status.
   *
   * sendHeaders will not set EOM flag in header frame, whereas
   * sendHeadersWithEOM will. sendHeadersWithOptionalEOM backs both of them.
   *
   * @param headers  Message headers
   */
	void sendHeaders(HTTPMessage headers)
	{
		sendHeadersWithOptionalEOM(headers,false);
	}

	void sendHeadersWithEOM(HTTPMessage headers)
	{
		sendHeadersWithOptionalEOM(headers,true);
	}

	void sendHeadersWithOptionalEOM(HTTPMessage headers, bool eom)
	{
		if(transport)
			transport.sendHeaders(this,headers,eom);
	}
	/**
   * Send part or all of the egress message body to the Transport. If flow
   * control is enabled, the chunk boundaries may not be respected.
   * This method does not actually write the message out on the wire
   * immediately. All writes happen at the end of the event loop at the
   * earliest.
   * Note: This method may be called zero or more times per message.
   *
   * @param body Message body data; the Transport will take care of
   *             applying any necessary protocol framing, such as
   *             chunk headers.
   */
	void sendBody(ubyte[] body_, bool iseom = false){
		if(transport)
			if(transport)transport.sendBody(this,body_, iseom);
	}

	void sendBody(ref HVector body_, bool iseom = false){
		if(transport)
			if(transport)transport.sendBody(this,body_, iseom);
	}
	
	/**
   * Write any protocol framing required for the subsequent call(s)
   * to sendBody(). This method does not actually write the message out on
   * the wire immediately. All writes happen at the end of the event loop
   * at the earliest.
   * @param length  Length in bytes of the body data to follow.
   */
	void sendChunkHeader(size_t length) {
		if(transport)
			transport.sendChunkHeader(this,length);
	}

	void socketWrite(ubyte[] data, Transport.SocketWriteCallBack cback){
		if(transport)
			transport.socketWrite(this,data, cback);
	}
	
	/**
   * Write any protocol syntax needed to terminate the data. This method
   * does not actually write the message out on the wire immediately. All
   * writes happen at the end of the event loop at the earliest.
   * Frame begun by the last call to sendChunkHeader().
   */
	void sendChunkTerminator() {
		if(transport)
			transport.sendChunkTerminator(this);
	}
	/**
   * Send part or all of the egress message body to the Transport. If flow
   * control is enabled, the chunk boundaries may not be respected.
   * This method does not actually write the message out on the wire
   * immediately. All writes happen at the end of the event loop at the
   * earliest.
   * Note: This method may be called zero or more times per message.
   *
   * @param body Message body data; the Transport will take care of
   *             applying any necessary protocol framing, such as
   *             chunk headers.
   */
	/**
   * Finalize the egress message; depending on the protocol used
   * by the Transport, this may involve sending an explicit "end
   * of message" indicator. This method does not actually write the
   * message out on the wire immediately. All writes happen at the end
   * of the event loop at the earliest.
   *
   * If the ingress message also is complete, the transaction may
   * detach itself from the Handler and Transport and delete itself
   * as part of this method.
   *
   * Note: Either this method or sendAbort() should be called once
   *       per message.
   */
	void sendEOM(){
		if(transport)
			transport.sendEOM(this);
	}

	void sendTimeOut()
	{
		if(!transport) return;
		import collie.codec.http.headers;
		scope HTTPMessage msg = new HTTPMessage();
		msg.statusCode(408);
		msg.statusMessage("Request Timeout");
		msg.getHeaders.add(HTTPHeaderCode.CONNECTION,"close");
		sendHeadersWithEOM(msg);
	}

	void sendWsData(OpCode code,ubyte[] data)
	{
		if(transport)
			transport.sendWsData(this,code,data);
	}

	void onWsFrame(ref WSFrame wsf){
		trace(".....");
		if(_handler)
			_handler.onWsFrame(wsf);
	}

	bool onUpgtade(CodecProtocol protocol, HTTPMessage msg){
		if(_handler)
			return _handler.onUpgtade(protocol, msg);

		return false;
	}

package:
	void onDelayedDestroy()
	{
		trace("deleting is ", deleting);
		if(deleting) return;
		deleting = true;
		if(_handler) {
			_handler.detachTransaction();
			_handler = null;
		}
		if(_transport) {
			_transport.detach(this);
			_transport = null;
		}
	}
private:
	HTTPCodec.StreamID _id;
	Transport _transport;
	HTTPTransactionHandler _handler;
	TransportDirection _direction;
	uint _seqNo;

	bool deleting = false;
private:
	ushort _lastResponseStatus;
}

