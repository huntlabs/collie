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
module collie.codec.mqtt.mqttdecoder;

import std.stdio;
import std.array;
import std.conv;
import std.experimental.allocator;
import std.experimental.allocator.gc_allocator;
import collie.codec.messagetobyteencoder;
import kiss.container.Vector;
import collie.codec.mqtt.bytebuf;
import collie.codec.mqtt.mqttcodecutil;
import collie.codec.mqtt.mqttconnackmessage;
import collie.codec.mqtt.mqttconnackvariableheader;
import collie.codec.mqtt.mqttconnectmsg;
import collie.codec.mqtt.mqttconnectpayload;
import collie.codec.mqtt.mqttconnectreturncode;
import collie.codec.mqtt.mqttconnectvariableheader;
import collie.codec.mqtt.mqttfixedheader;
import collie.codec.mqtt.mqttmsg;
import collie.codec.mqtt.mqttmsgidvariableheader;
import collie.codec.mqtt.mqttmsgtype;
import collie.codec.mqtt.mqttpubackmsg;
import collie.codec.mqtt.mqttpublishmsg;
import collie.codec.mqtt.mqttpublishpayload;
import collie.codec.mqtt.mqttpublishvariableheader;
import collie.codec.mqtt.mqttqos;
import collie.codec.mqtt.mqttsubackmsg;
import collie.codec.mqtt.mqttsubackpayload;
import collie.codec.mqtt.mqttsubscribemsg;
import collie.codec.mqtt.mqttsubscribepayload;
import collie.codec.mqtt.mqtttopicsubscription;
import collie.codec.mqtt.mqttunsubscribemsg;
import collie.codec.mqtt.mqttunsubscribepayload;
import collie.codec.mqtt.mqttversion;

import collie.channel.handler;
import collie.codec.bytetomessagedecoder;

 final class Result(T) {
	
	this(T _value, int _numberOfBytesConsumed) {
		this.value = _value;
		this.numberOfBytesConsumed = _numberOfBytesConsumed;
	}
private:
	 T value;
	 int numberOfBytesConsumed;
}

 class MqttDecoder :ByteToMessageDecoder!(MqttMsg[]) {

public:
	 this() {
		this(DEFAULT_MAX_BYTES_IN_MESSAGE);
	}
	
	 this(int maxBytesInMessage) {
		//super(DecoderState.READ_FIXED_HEADER);
		_curstat = DecoderState.READ_FIXED_HEADER;
		this.maxBytesInMessage = maxBytesInMessage;
	}

	override void read(Context ctx, ubyte[] msg)
	{
		bool success = true;
		MqttMsg[] result;
		success = decode(ctx, msg, result);
		if (success)
		{
			ctx.fireRead(result);
		}
	}

	override bool decode(Context ctx, ubyte[] buf, ref MqttMsg[] mqs) {
		bool res = true;
		ByteBuf buffer = new ByteBuf(buf);
		//writeln("new bytebuf readerindex : --> ",buffer.readerIndex()," writeindex : ",buffer.writerIndex());
		//writeln(buffer.data);
		//writeln("new bytebuf len :",buffer.length," buf len : ",buf.length);
		while(1)
		{
			if(_curstat == DecoderState.BAD_MESSAGE || _curstat == DecoderState.DECODE_FINISH)
				break;
			switch (_curstat) {
				case DecoderState.READ_FIXED_HEADER:
					//writeln("decodeFixedHeader before ------------");
					mqttFixedHeader = decodeFixedHeader(buffer);
					bytesRemainingInVariablePart = mqttFixedHeader.remainingLength();
					_curstat = DecoderState.READ_VARIABLE_HEADER;
					// fall through
					break;
				case DecoderState.READ_VARIABLE_HEADER:
					if (bytesRemainingInVariablePart > maxBytesInMessage) {
						throw new Exception("too large message: " ~ to!string(bytesRemainingInVariablePart) ~ " bytes");
					}
					//writeln("decodeVariableHeader before ------------");
					// Result!(Object) decodedVariableHeader = decodeVariableHeader(buffer, mqttFixedHeader);
					switch (mqttFixedHeader.messageType()) {
						case MqttMsgType.CONNECT:
							auto decodedVariableHeader = decodeConnectionVariableHeader(buffer);
							variableHeader = decodedVariableHeader.value;
							bytesRemainingInVariablePart -= decodedVariableHeader.numberOfBytesConsumed;
							break;
							
						case MqttMsgType.CONNACK:
							auto decodedVariableHeader = decodeConnAckVariableHeader(buffer);
							variableHeader = decodedVariableHeader.value;
							bytesRemainingInVariablePart -= decodedVariableHeader.numberOfBytesConsumed;
							break;
							
						case MqttMsgType.SUBSCRIBE:
						case MqttMsgType.UNSUBSCRIBE:
						case MqttMsgType.SUBACK:
						case MqttMsgType.UNSUBACK:
						case MqttMsgType.PUBACK:
						case MqttMsgType.PUBREC:
						case MqttMsgType.PUBCOMP:
						case MqttMsgType.PUBREL:
							auto decodedVariableHeader = decodeMessageIdVariableHeader(buffer);
							variableHeader = decodedVariableHeader.value;
							bytesRemainingInVariablePart -= decodedVariableHeader.numberOfBytesConsumed;
							break;
							
						case MqttMsgType.PUBLISH:
							auto decodedVariableHeader = decodePublishVariableHeader(buffer, mqttFixedHeader);
							variableHeader = decodedVariableHeader.value;
							bytesRemainingInVariablePart -= decodedVariableHeader.numberOfBytesConsumed;
							break;
							
						case MqttMsgType.PINGREQ:
						case MqttMsgType.PINGRESP:
						case MqttMsgType.DISCONNECT:
							// Empty variable header

						default:
							auto decodedVariableHeader = new Result!(Object)(null, 0);
							variableHeader = decodedVariableHeader.value;
							bytesRemainingInVariablePart -= decodedVariableHeader.numberOfBytesConsumed;
							break;
					}

					_curstat = DecoderState.READ_PAYLOAD;

					// fall through
					break;
				case DecoderState.READ_PAYLOAD:
					//writeln("DecoderState.READ_PAYLOAD  begin------------");
//					 Result!(Object) decodedPayload =
//						decodePayload(
//							buffer,
//							mqttFixedHeader.messageType(),
//							bytesRemainingInVariablePart,
//							variableHeader);
//					payload = decodedPayload.value;
//					bytesRemainingInVariablePart -= decodedPayload.numberOfBytesConsumed;

					switch (mqttFixedHeader.messageType()) {
						case MqttMsgType.CONNECT:
							auto  decodedPayload = decodeConnectionPayload(buffer, cast(MqttConnectVariableHeader) variableHeader);
							payload = decodedPayload.value;
							bytesRemainingInVariablePart -= decodedPayload.numberOfBytesConsumed;
							mqs ~= new MqttConnectMsg(mqttFixedHeader, cast(MqttConnectVariableHeader)variableHeader, cast(MqttConnectPayload)payload);
							break;
							
						case MqttMsgType.SUBSCRIBE:
							auto  decodedPayload = decodeSubscribePayload(buffer, bytesRemainingInVariablePart);
							payload = decodedPayload.value;
							bytesRemainingInVariablePart -= decodedPayload.numberOfBytesConsumed;
							mqs ~= new MqttSubscribeMsg(mqttFixedHeader, cast(MqttMsgIdVariableHeader)variableHeader, cast(MqttSubscribePayload)payload);
							break;

						case MqttMsgType.SUBACK:
							auto  decodedPayload = decodeSubackPayload(buffer, bytesRemainingInVariablePart);
							payload = decodedPayload.value;
							bytesRemainingInVariablePart -= decodedPayload.numberOfBytesConsumed;
							mqs ~= new MqttSubAckMsg(mqttFixedHeader, cast(MqttMsgIdVariableHeader)variableHeader, cast(MqttSubAckPayload)payload);
							break;
							
						case MqttMsgType.UNSUBSCRIBE:
							auto  decodedPayload = decodeUnsubscribePayload(buffer, bytesRemainingInVariablePart);
							payload = decodedPayload.value;
							bytesRemainingInVariablePart -= decodedPayload.numberOfBytesConsumed;
							mqs ~= new MqttUnsubscribeMsg(mqttFixedHeader, cast(MqttMsgIdVariableHeader)variableHeader, cast(MqttUnsubscribePayload)payload);
							break;
							
						case MqttMsgType.PUBLISH:
							auto  decodedPayload = decodePublishPayload(buffer, bytesRemainingInVariablePart);
							payload = decodedPayload.value;
							bytesRemainingInVariablePart -= decodedPayload.numberOfBytesConsumed;
							mqs ~= new MqttPublishMsg(mqttFixedHeader, cast(MqttPublishVariableHeader)variableHeader, cast(MqttPublishPayload)payload);
							break;
						case MqttMsgType.CONNACK:
							mqs ~= new MqttConnAckMessage(mqttFixedHeader, cast(MqttConnAckVariableHeader)variableHeader);
							break;
						default:
							// unknown payload , no byte consumed
							auto  decodedPayload = new Result!(Object)(null, 0);
							payload = decodedPayload.value;
							bytesRemainingInVariablePart -= decodedPayload.numberOfBytesConsumed;
							mqs ~= new MqttMsg(mqttFixedHeader, variableHeader, payload);
							break;

					}

					if (bytesRemainingInVariablePart != 0) {
						throw new Exception(
							"non-zero remaining payload bytes: " ~
							to!string(bytesRemainingInVariablePart) ~ " (" ~ to!string(mqttFixedHeader.messageType()) ~ ')');
					}

					mqttFixedHeader = null;
					variableHeader = null;
					payload = null;

					//writeln(" bytebuf readerindex : --> ",buffer.readerIndex()," writeindex : ",buffer.writerIndex(),"  len : ",buffer.length);
					if(buffer.readerIndex == buffer.length) //解码完毕
						_curstat = DecoderState.DECODE_FINISH;
					else
						_curstat = DecoderState.READ_FIXED_HEADER; //解析下条消息

					break;
					
				case DecoderState.BAD_MESSAGE:
					// Keep discarding until disconnection.
					buffer.skipBytes(cast(int)buffer.length);
					break;
					
				default:
					// Shouldn't reach here.
					throw new Exception("decoder error");
			}
		}

		_curstat = DecoderState.READ_FIXED_HEADER;

		return res;
	}

private:
//	 MqttMsg invalidMessage(Throwable cause) {
//		checkpoint(DecoderState.BAD_MESSAGE);
//		return MqttMessageFactory.newInvalidMessage(cause);
//	}
	
	/**
     * Decodes the fixed header. It's one byte for the flags and then variable bytes for the remaining length.
     *
     * @param buffer the buffer to decode from
     * @return the fixed header
     */
	 static MqttFixedHeader decodeFixedHeader(ref ByteBuf buffer) {
		short b1 = buffer.readUnsignedByte();
		
		MqttMsgType messageType = to!MqttMsgType(b1 >> 4);
		bool dupFlag = (b1 & 0x08) == 0x08;
		int qosLevel = (b1 & 0x06) >> 1;
		bool retain = (b1 & 0x01) != 0;
		
		int remainingLength = 0;
		int multiplier = 1;
		short digit;
		int loops = 0;
		do {
			digit = buffer.readUnsignedByte();
			remainingLength += (digit & 127) * multiplier;
			multiplier *= 128;
			loops++;
		} while ((digit & 128) != 0 && loops < 4);
		
		// MQTT protocol limits Remaining Length to 4 bytes
		if (loops == 4 && (digit & 128) != 0) {
			throw new Exception("remaining length exceeds 4 digits (" ~ to!string(messageType) ~ ')');
		}
		MqttFixedHeader decodedFixedHeader =
			new MqttFixedHeader(messageType, dupFlag, to!(MqttQoS)(qosLevel), retain, remainingLength);
		return MqttCodecUtil.validateFixedHeader(MqttCodecUtil.resetUnusedFields(decodedFixedHeader));
	}

	/**
     * Decodes the variable header (if any)
     * @param buffer the buffer to decode from
     * @param mqttFixedHeader MqttFixedHeader of the same message
     * @return the variable header
     */
	 static Result!(Object) decodeVariableHeader(ref ByteBuf buffer, MqttFixedHeader mqttFixedHeader) {
		switch (mqttFixedHeader.messageType()) {
			case MqttMsgType.CONNECT:
				return cast(Result!(Object))(decodeConnectionVariableHeader(buffer));
				
			case MqttMsgType.CONNACK:
				return to!(Result!(Object))(decodeConnAckVariableHeader(buffer));
				
			case MqttMsgType.SUBSCRIBE:
			case MqttMsgType.UNSUBSCRIBE:
			case MqttMsgType.SUBACK:
			case MqttMsgType.UNSUBACK:
			case MqttMsgType.PUBACK:
			case MqttMsgType.PUBREC:
			case MqttMsgType.PUBCOMP:
			case MqttMsgType.PUBREL:
				return to!(Result!(Object))(decodeMessageIdVariableHeader(buffer));
				
			case MqttMsgType.PUBLISH:
				return to!(Result!(Object))(decodePublishVariableHeader(buffer, mqttFixedHeader));
				
			case MqttMsgType.PINGREQ:
			case MqttMsgType.PINGRESP:
			case MqttMsgType.DISCONNECT:
				// Empty variable header
				return new Result!(Object)(null, 0);
			default:
				return new Result!(Object)(null, 0);
		}

	}

	 static Result!(MqttConnectVariableHeader) decodeConnectionVariableHeader(ref ByteBuf buffer) {
		Result!(string) protoString = decodeString(buffer);
		int numberOfBytesConsumed = protoString.numberOfBytesConsumed;
		
		byte protocolLevel = buffer.readByte();
		numberOfBytesConsumed += 1;
		//writeln("decoder ---> ",to!string(protoString.value), protocolLevel);
		MqttVersion mqttVersion = MqttVersion.fromProtocolNameAndLevel(cast(string)protoString.value, protocolLevel);
		
		int b1 = buffer.readUnsignedByte();
		numberOfBytesConsumed += 1;
		
		Result!(int) keepAlive = decodeMsbLsb(buffer);
		numberOfBytesConsumed += keepAlive.numberOfBytesConsumed;
		
		bool hasUserName = (b1 & 0x80) == 0x80;
		bool hasPassword = (b1 & 0x40) == 0x40;
		bool willRetain = (b1 & 0x20) == 0x20;
		int willQos = (b1 & 0x18) >> 3;
		bool willFlag = (b1 & 0x04) == 0x04;
		bool cleanSession = (b1 & 0x02) == 0x02;
		if (mqttVersion.protocolName() == "MQTT") {
			bool zeroReservedFlag = (b1 & 0x01) == 0x0;
			if (!zeroReservedFlag) {
				// MQTT v3.1.1: The Server MUST validate that the reserved flag in the CONNECT Control Packet is
				// set to zero and disconnect the Client if it is not zero.
				// See http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc385349230
				throw new Exception("non-zero reserved flag");
			}
		}
		
		MqttConnectVariableHeader mqttConnectVariableHeader = new MqttConnectVariableHeader(
			mqttVersion.protocolName(),
			mqttVersion.protocolLevel(),
			hasUserName,
			hasPassword,
			willRetain,
			willQos,
			willFlag,
			cleanSession,
			keepAlive.value);
		return new Result!(MqttConnectVariableHeader)(mqttConnectVariableHeader, numberOfBytesConsumed);
	}
	
	 static Result!(MqttConnAckVariableHeader) decodeConnAckVariableHeader(ref ByteBuf buffer) {
		bool sessionPresent = (buffer.readUnsignedByte() & 0x01) == 0x01;
		byte returnCode = cast(byte)buffer.readByte();
		int numberOfBytesConsumed = 2;
		MqttConnAckVariableHeader mqttConnAckVariableHeader =
			new MqttConnAckVariableHeader(to!(MqttConnectReturnCode)(returnCode), sessionPresent);
		return new Result!(MqttConnAckVariableHeader)(mqttConnAckVariableHeader, numberOfBytesConsumed);
	}
	
	 static Result!(MqttMsgIdVariableHeader) decodeMessageIdVariableHeader(ref ByteBuf buffer) {
		Result!(int) messageId = decodeMessageId(buffer);
		return new Result!(MqttMsgIdVariableHeader)(
			to!MqttMsgIdVariableHeader(MqttMsgIdVariableHeader.from(messageId.value)),
			messageId.numberOfBytesConsumed);
	}
	
	 static Result!(MqttPublishVariableHeader) decodePublishVariableHeader(
		ref ByteBuf buffer,
		MqttFixedHeader mqttFixedHeader) {
		Result!(string) decodedTopic = decodeString(buffer);
		if (!MqttCodecUtil.isValidPublishTopicName(decodedTopic.value)) {
			throw new Exception("invalid publish topic name: " ~ decodedTopic.value ~ " (contains wildcards)");
		}
		int numberOfBytesConsumed = decodedTopic.numberOfBytesConsumed;
		
		int messageId = -1;
		if (to!int(mqttFixedHeader.qosLevel()) > 0) {
			Result!(int) decodedMessageId = decodeMessageId(buffer);
			messageId = decodedMessageId.value;
			numberOfBytesConsumed += decodedMessageId.numberOfBytesConsumed;
		}
		MqttPublishVariableHeader mqttPublishVariableHeader =
			new MqttPublishVariableHeader(decodedTopic.value, messageId);
		return new Result!(MqttPublishVariableHeader)(mqttPublishVariableHeader, numberOfBytesConsumed);
	}
	
	 static Result!(int) decodeMessageId(ref ByteBuf buffer) {
		Result!(int) messageId = decodeMsbLsb(buffer);
		if (!MqttCodecUtil.isValidMessageId(messageId.value)) {
			throw new Exception("invalid messageId: " ~ to!string(messageId.value));
		}
		return messageId;
	}
	
	/**
     * Decodes the payload.
     *
     * @param buffer the buffer to decode from
     * @param messageType  type of the message being decoded
     * @param bytesRemainingInVariablePart bytes remaining
     * @param variableHeader variable header of the same message
     * @return the payload
     */
	 static Result!(Object) decodePayload(
		ref ByteBuf buffer,
		MqttMsgType messageType,
		int bytesRemainingInVariablePart,
		Object variableHeader) {
		switch (messageType) {
			case MqttMsgType.CONNECT:
				return to!(Result!(Object))(decodeConnectionPayload(buffer, cast(MqttConnectVariableHeader) variableHeader));
				
			case MqttMsgType.SUBSCRIBE:
				return to!(Result!(Object))(decodeSubscribePayload(buffer, bytesRemainingInVariablePart));
				
			case MqttMsgType.SUBACK:
				return to!(Result!(Object))(decodeSubackPayload(buffer, bytesRemainingInVariablePart));
				
			case MqttMsgType.UNSUBSCRIBE:
				return to!(Result!(Object))(decodeUnsubscribePayload(buffer, bytesRemainingInVariablePart));
				
			case MqttMsgType.PUBLISH:
				return to!(Result!(Object))(decodePublishPayload(buffer, bytesRemainingInVariablePart));
				
			default:
				// unknown payload , no byte consumed
				return new Result!(Object)(null, 0);
		}
	}
	
	 static Result!(MqttConnectPayload) decodeConnectionPayload(
		ref ByteBuf buffer,
		MqttConnectVariableHeader mqttConnectVariableHeader) {
		//writeln("decodeConnectionPayload ---begin----");
		Result!(string) decodedClientId = decodeString(buffer);

		string decodedClientIdValue = decodedClientId.value;

		MqttVersion mqttVersion = MqttVersion.fromProtocolNameAndLevel(mqttConnectVariableHeader.name(),
			 to!byte(mqttConnectVariableHeader.mqtt_version()));
		if (!MqttCodecUtil.isValidClientId(mqttVersion, decodedClientIdValue)) {
			throw new Exception("invalid clientIdentifier: " ~ decodedClientIdValue);
		}
		int numberOfBytesConsumed = decodedClientId.numberOfBytesConsumed;
		
		Result!(string) decodedWillTopic = null;
		Result!(string) decodedWillMessage = null;
		if (mqttConnectVariableHeader.isWillFlag()) {

			decodedWillTopic = decodeString(buffer, 0, 32767);
			//writeln("decodeConnectionPayload ---end----");
			numberOfBytesConsumed += decodedWillTopic.numberOfBytesConsumed;
			decodedWillMessage = decodeAsciiString(buffer);
			numberOfBytesConsumed += decodedWillMessage.numberOfBytesConsumed;
		}
		Result!(string) decodedUserName = null;
		Result!(string) decodedPassword = null;
		if (mqttConnectVariableHeader.hasUserName()) {
			decodedUserName = decodeString(buffer);
			numberOfBytesConsumed += decodedUserName.numberOfBytesConsumed;
		}
		if (mqttConnectVariableHeader.hasPassword()) {
			decodedPassword = decodeString(buffer);
			numberOfBytesConsumed += decodedPassword.numberOfBytesConsumed;
		}
		
		MqttConnectPayload mqttConnectPayload =
			new MqttConnectPayload(
				decodedClientId.value,
				decodedWillTopic !is null ? decodedWillTopic.value : null,
				decodedWillMessage !is null ? decodedWillMessage.value : null,
				decodedUserName !is null ? decodedUserName.value : null,
				decodedPassword !is null ? decodedPassword.value : null);
		return new Result!(MqttConnectPayload)(mqttConnectPayload, numberOfBytesConsumed);
	}
	
	 static Result!(MqttSubscribePayload) decodeSubscribePayload(
		ref ByteBuf buffer,
		int bytesRemainingInVariablePart) {
		MqttTopicSubscription[] subscribeTopics ;
		int numberOfBytesConsumed = 0;
		while (numberOfBytesConsumed < bytesRemainingInVariablePart) {
			Result!(string) decodedTopicName = decodeString(buffer);
			numberOfBytesConsumed += decodedTopicName.numberOfBytesConsumed;
			int qos = buffer.readUnsignedByte() & 0x03;
			numberOfBytesConsumed++;
			subscribeTopics ~= new MqttTopicSubscription(decodedTopicName.value, to!MqttQoS(qos));
		}
		return new Result!(MqttSubscribePayload)(new MqttSubscribePayload(subscribeTopics), numberOfBytesConsumed);
	}

	 static Result!(MqttSubAckPayload) decodeSubackPayload(
		ref ByteBuf buffer,
		int bytesRemainingInVariablePart) {
		int[] grantedQos ;
		int numberOfBytesConsumed = 0;
		while (numberOfBytesConsumed < bytesRemainingInVariablePart) {
			int qos = buffer.readUnsignedByte() & 0x03;
			numberOfBytesConsumed++;
			grantedQos ~= qos;
		}
		return new Result!(MqttSubAckPayload)(new MqttSubAckPayload(grantedQos), numberOfBytesConsumed);
	}
	
	 static Result!(MqttUnsubscribePayload) decodeUnsubscribePayload(
		ref ByteBuf buffer,
		int bytesRemainingInVariablePart) {
		string[] unsubscribeTopics;
		int numberOfBytesConsumed = 0;
		while (numberOfBytesConsumed < bytesRemainingInVariablePart) {
			Result!(string) decodedTopicName = decodeString(buffer);
			numberOfBytesConsumed += decodedTopicName.numberOfBytesConsumed;
			unsubscribeTopics ~= decodedTopicName.value;
		}
		return new Result!(MqttUnsubscribePayload)(
			new MqttUnsubscribePayload(unsubscribeTopics),
			numberOfBytesConsumed);
	}
	
	static Result!(MqttPublishPayload) decodePublishPayload(ref ByteBuf buffer, int bytesRemainingInVariablePart) {
		ByteBuf b = buffer.readSlice(bytesRemainingInVariablePart);
		return new Result!(MqttPublishPayload)(new MqttPublishPayload(b.data()), bytesRemainingInVariablePart);
	}

	 static Result!(string) decodeString(ref ByteBuf buffer) {
		return decodeString(buffer, 0, int.max);
	}
	
	 static Result!(string) decodeAsciiString(ref ByteBuf buffer) {
		Result!(string) result = decodeString(buffer, 0, int.max);
		string s = result.value;
		for (int i = 0; i < s.length; i++) {
			if (s[i] > 127) {
				return new Result!(string)(null, result.numberOfBytesConsumed);
			}
		}
		return new Result!(string)(s, result.numberOfBytesConsumed);
	}
	
	 static Result!(string) decodeString(ref ByteBuf buffer, int minBytes, int maxBytes) {
		Result!(int) decodedSize = decodeMsbLsb(buffer);
		int size = decodedSize.value;
		int numberOfBytesConsumed = decodedSize.numberOfBytesConsumed;
		if (size < minBytes || size > maxBytes) {
			buffer.skipBytes(size);
			numberOfBytesConsumed += size;
			return new Result!(string)(null, numberOfBytesConsumed);
		}
		string s = buffer.toString(buffer.readerIndex(), size);
		buffer.skipBytes(size);
		numberOfBytesConsumed += size;
		return new Result!(string)(s, numberOfBytesConsumed);
	}
	
	 static Result!(int) decodeMsbLsb(ref ByteBuf buffer) {
		return decodeMsbLsb(buffer, 0, 65535);
	}
	
	 static Result!(int) decodeMsbLsb(ref ByteBuf buffer, int min, int max) {
		short msbSize = buffer.readUnsignedByte();
		short lsbSize = buffer.readUnsignedByte();
		int numberOfBytesConsumed = 2;

		int result = msbSize << 8 | lsbSize;
		if (result < min || result > max) {
			result = -1;
		}
		//writeln("msbSize : ",msbSize, " lsbSize : ",lsbSize, " result : ",result);
		return new Result!(int)(result, numberOfBytesConsumed);
	}

public:
//	MqttMsgType getMsgType()
//	{
//		if(mqttFixedHeader !is null)
//			return mqttFixedHeader.messageType();
//		return MqttMsgType.UNKNOWN;
//	}

private:
	 static  int DEFAULT_MAX_BYTES_IN_MESSAGE = 8092;
	
	/**
     * States of the decoder.
     * We start at READ_FIXED_HEADER, followed by
     * READ_VARIABLE_HEADER and finally READ_PAYLOAD.
     */
	enum DecoderState {
		READ_FIXED_HEADER,
		READ_VARIABLE_HEADER,
		READ_PAYLOAD,
		BAD_MESSAGE,
		DECODE_FINISH,
	}
	 DecoderState _curstat;
	 MqttFixedHeader mqttFixedHeader;
	 Object variableHeader;
	 Object payload;
	 int bytesRemainingInVariablePart;
	
	 int maxBytesInMessage;
}

