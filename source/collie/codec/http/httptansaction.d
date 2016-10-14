module collie.codec.http.httptansaction;

import collie.codec.http.codec.httpcodec;
import collie.codec.http.httpmessage;
import collie.codec.http.errocode;

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
	void onError(string erromsg);
	
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
}

class httptansaction
{
	interface Transport
	{
		void pauseIngress(HTTPTransaction txn);
		
		void resumeIngress(HTTPTransaction txn);
		
		void transactionTimeout(HTTPTransaction txn);
		
		void sendHeaders(HTTPTransaction txn,
			const HTTPMessage headers,
			//HTTPHeaderSize* size,
			bool eom);
		
		size_t sendBody(HTTPTransaction txn,
			ubyte[],
			bool eom);
		
		size_t sendChunkHeader(HTTPTransaction txn,
			size_t length);
		
		size_t sendChunkTerminator(HTTPTransaction txn);

		
		size_t sendEOM(HTTPTransaction txn);

		size_t sendAbort(HTTPTransaction txn,
			HTTPErrorCode statusCode);
		
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

		
		HTTPCodec getCodec() const;
		
		bool isDraining() const = 0;

	}

	this(TransportDirection direction, HTTPCodec.StreamID id,uint seqNo,Transport port)
	{
		_id = id;
		_transport = port;
	}
	@property HTTPTransactionHandler handler(){return _handler;}
	@property void handler(HTTPTransactionHandler han){_handler = han;}

	bool isUpstream() const {
		return _direction == TransportDirection.UPSTREAM;
	}
	
	bool isDownstream() const {
		return _direction == TransportDirection.DOWNSTREAM;
	}


	HTTPCodec.StreamID getID() const { return id; }

	Address getLocalAddress(){return _transport.getLocalAddress();}
	
	Address getPeerAddress(){return _transport.getPeerAddress();}

private:
	HTTPCodec.StreamID _id;
	Transport _transport;
	HTTPTransactionHandler _handler;
	TransportDirection _direction;
}

