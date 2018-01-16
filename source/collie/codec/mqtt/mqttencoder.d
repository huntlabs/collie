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
module collie.codec.mqtt.mqttencoder;

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

import collie.codec.messagetobyteencoder;

 class MqttEncoder :MessageToByteEncoder!MqttMsg{

	 override ubyte[] encode(ref MqttMsg msg){
		return doEncode(msg).data();
	}

	override void callBack(ubyte[] data, size_t len)
	{
	}
	/**
     * This is the main encoding method.
     * It's only visible for testing.
     *
     * @param byteBufAllocator Allocates ByteBuf
     * @param message MQTT message to encode
     * @return ByteBuf with encoded bytes
     */
public:
	static ByteBuf doEncode(MqttMsg message) {
		
		switch (message.fixedHeader().messageType()) {
			case MqttMsgType.CONNECT:
				return encodeConnectMessage( cast(MqttConnectMsg) message);
				
			case MqttMsgType.CONNACK:
				return encodeConnAckMessage(cast(MqttConnAckMessage) message);
				
			case MqttMsgType.PUBLISH:
				return encodePublishMessage( cast(MqttPublishMsg) message);

			case MqttMsgType.SUBSCRIBE:
				return encodeSubscribeMessage( cast(MqttSubscribeMsg) message);

			case MqttMsgType.UNSUBSCRIBE:
				return encodeUnsubscribeMessage(cast(MqttUnsubscribeMsg) message);
				
			case MqttMsgType.SUBACK:
				return encodeSubAckMessage( cast(MqttSubAckMsg) message);
				
			case MqttMsgType.UNSUBACK:
			case MqttMsgType.PUBACK:
			case MqttMsgType.PUBREC:
			case MqttMsgType.PUBREL:
			case MqttMsgType.PUBCOMP:
				return encodeMessageWithOnlySingleByteFixedHeaderAndMessageId(message);
				
			case MqttMsgType.PINGREQ:
			case MqttMsgType.PINGRESP:
			case MqttMsgType.DISCONNECT:
				return encodeMessageWithOnlySingleByteFixedHeader(message);
				
			default:
				throw new Exception(
					"Unknown message type: " ~ to!string(message.fixedHeader().messageType()));
		}
	}
private:
	 static ByteBuf encodeConnectMessage(
		MqttConnectMsg message) {
		int payloadBufferSize = 0;
		
		MqttFixedHeader mqttFixedHeader = message.fixedHeader();
		MqttConnectVariableHeader variableHeader = message.variableHeader();
		MqttConnectPayload payload = message.payload();
		MqttVersion mqttVersion = MqttVersion.fromProtocolNameAndLevel(variableHeader.name(),cast(byte) variableHeader.mqtt_version());
		
		// Client id
		string clientIdentifier = payload.clientIdentifier();
		if (!MqttCodecUtil.isValidClientId(mqttVersion, clientIdentifier)) {
			throw new Exception("invalid clientIdentifier: " ~ clientIdentifier);
		}
		//("clientIdentifier :"~clientIdentifier);
		ubyte[] clientIdentifierBytes = cast(ubyte[])(clientIdentifier);

		//writeln("clientIdentifierBytes :-->");
		//writeln(clientIdentifierBytes);
		payloadBufferSize += 2 + clientIdentifierBytes.length;
		
		// Will topic and message
		string willTopic = payload.willTopic();
		ubyte[] willTopicBytes = cast(ubyte[])(willTopic);
		string willMessage = payload.willMessage();
		ubyte[] willMessageBytes = cast(ubyte[])(willMessage) ;
		if (variableHeader.isWillFlag()) {
			payloadBufferSize += 2 + willTopicBytes.length;
			payloadBufferSize += 2 + willMessageBytes.length;
		}
		
		string userName = payload.userName();
		ubyte[] userNameBytes =  cast(ubyte[])(userName) ;
		if (variableHeader.hasUserName()) {
			payloadBufferSize += 2 + userNameBytes.length;
		}

		string password = payload.password();
		ubyte[] passwordBytes = cast(ubyte[])(password) ;
		if (variableHeader.hasPassword()) {
			payloadBufferSize += 2 + passwordBytes.length;
		}
		
		// Fixed header
		//writeln("protocolName -->",mqttVersion.protocolName());
		ubyte[] protocolNameBytes = cast(ubyte[])(mqttVersion.protocolName());
		int variableHeaderBufferSize = 2 +cast(int)protocolNameBytes.length + 4;
		int variablePartSize = variableHeaderBufferSize + payloadBufferSize;
		int fixedHeaderBufferSize = 1 + getVariableLengthInt(variablePartSize);

	

		ByteBuf buf = new ByteBuf;
		buf.writeByte(getFixedHeaderByte1(mqttFixedHeader));
		writeVariableLengthInt(buf, variablePartSize);
		
		buf.writeShort(cast(int)protocolNameBytes.length);
		buf.writeBytes(protocolNameBytes);
		
		buf.writeByte(cast(ubyte)variableHeader.mqtt_version());
		buf.writeByte(getConnVariableHeaderFlag(variableHeader));
		buf.writeShort(variableHeader.keepAliveTimeSeconds());
		
		// Payload
		buf.writeShort(cast(int)clientIdentifierBytes.length);
		//writeln("clientIdentifierBytes len ---->: ",clientIdentifierBytes.length);
		buf.writeBytes(clientIdentifierBytes, 0, cast(int)clientIdentifierBytes.length);
		if (variableHeader.isWillFlag()) {
			buf.writeShort(cast(int)willTopicBytes.length);
			buf.writeBytes(willTopicBytes, 0, cast(int)willTopicBytes.length);
			buf.writeShort(cast(int)willMessageBytes.length);
			buf.writeBytes(willMessageBytes, 0, cast(int)willMessageBytes.length);
		}
		if (variableHeader.hasUserName()) {
			buf.writeShort(cast(int)userNameBytes.length);
			buf.writeBytes(userNameBytes, 0, cast(int)userNameBytes.length);
		}
		if (variableHeader.hasPassword()) {
			buf.writeShort(cast(int)passwordBytes.length);
			buf.writeBytes(passwordBytes, 0,cast(int)passwordBytes.length);
		}

		return buf;
	}
	
	 static int getConnVariableHeaderFlag(MqttConnectVariableHeader variableHeader) {
		int flagByte = 0;
		if (variableHeader.hasUserName()) {
			flagByte |= 0x80;
		}
		if (variableHeader.hasPassword()) {
			flagByte |= 0x40;
		}
		if (variableHeader.isWillRetain()) {
			flagByte |= 0x20;
		}
		flagByte |= (variableHeader.willQos() & 0x03) << 3;
		if (variableHeader.isWillFlag()) {
			flagByte |= 0x04;
		}
		if (variableHeader.isCleanSession()) {
			flagByte |= 0x02;
		}
		return flagByte;
	}
	
	 static ByteBuf encodeConnAckMessage(
		MqttConnAckMessage message) {

		ByteBuf buf = new ByteBuf;
		buf.writeByte(getFixedHeaderByte1(message.fixedHeader()));
		buf.writeByte(cast(ubyte)(2 & 0xff));
		buf.writeByte(message.variableHeader().isSessionPresent() ? 0x01 : 0x00);

		buf.writeByte(cast(ubyte)(message.variableHeader().connectReturnCode()));

		return buf;
	}
	
	 static ByteBuf encodeSubscribeMessage(
		MqttSubscribeMsg message) {
		int variableHeaderBufferSize = 2;
		int payloadBufferSize = 0;
		
		MqttFixedHeader mqttFixedHeader = message.fixedHeader();
		MqttMsgIdVariableHeader variableHeader = message.variableHeader();
		MqttSubscribePayload payload = message.payload();
		
		foreach (MqttTopicSubscription topic ; payload.topicSubscriptions()) {
			string topicName = topic.topicName();
			ubyte[] topicNameBytes = cast(ubyte[])(topicName);
			payloadBufferSize += 2 + topicNameBytes.length;
			payloadBufferSize += 1;
		}
		
		int variablePartSize = variableHeaderBufferSize + payloadBufferSize;
		int fixedHeaderBufferSize = 1 + getVariableLengthInt(variablePartSize);
		
		ByteBuf buf = new ByteBuf;
		buf.writeByte(getFixedHeaderByte1(mqttFixedHeader));
		writeVariableLengthInt(buf, variablePartSize);
		
		// Variable Header
		int messageId = variableHeader.messageId();
		buf.writeShort(messageId);
		
		// Payload
		foreach (MqttTopicSubscription topic ; payload.topicSubscriptions()) {
			string topicName = topic.topicName();
			ubyte[] topicNameBytes = cast(ubyte[])(topicName);
			buf.writeShort(cast(int)topicNameBytes.length);
			buf.writeBytes(topicNameBytes, 0, cast(int)topicNameBytes.length);
			buf.writeByte(to!(int)(topic.qualityOfService()));
		}
		
		return buf;
	}
	
	 static ByteBuf encodeUnsubscribeMessage(
		MqttUnsubscribeMsg message) {
		int variableHeaderBufferSize = 2;
		int payloadBufferSize = 0;
		
		MqttFixedHeader mqttFixedHeader = message.fixedHeader();
		MqttMsgIdVariableHeader variableHeader = message.variableHeader();
		MqttUnsubscribePayload payload = message.payload();
		
		foreach (string topicName ; payload.topics()) {
			ubyte[] topicNameBytes = cast(ubyte[])(topicName);
			payloadBufferSize += 2 + topicNameBytes.length;
		}
		
		int variablePartSize = variableHeaderBufferSize + payloadBufferSize;
		int fixedHeaderBufferSize = 1 + getVariableLengthInt(variablePartSize);
		
		ByteBuf buf = new ByteBuf;
		buf.writeByte(getFixedHeaderByte1(mqttFixedHeader));
		writeVariableLengthInt(buf, variablePartSize);
		
		// Variable Header
		int messageId = variableHeader.messageId();
		buf.writeShort(messageId);
		
		// Payload
		foreach (string topicName ; payload.topics()) {
			ubyte[] topicNameBytes = cast(ubyte[])(topicName);
			buf.writeShort(cast(int)topicNameBytes.length);
			buf.writeBytes(topicNameBytes, 0, cast(int)topicNameBytes.length);
		}
		
		return buf;
	}
	
	 static ByteBuf encodeSubAckMessage(
		MqttSubAckMsg message) {
		int variableHeaderBufferSize = 2;
		int payloadBufferSize = cast(int)message.payload().grantedQoSLevels().length;
		int variablePartSize = variableHeaderBufferSize + payloadBufferSize;
		int fixedHeaderBufferSize = 1 + getVariableLengthInt(variablePartSize);
		ByteBuf buf = new ByteBuf;
		buf.writeByte(getFixedHeaderByte1(message.fixedHeader()));
		writeVariableLengthInt(buf, variablePartSize);
		buf.writeShort(message.variableHeader().messageId());
		foreach (int qos ; message.payload().grantedQoSLevels()) {
			buf.writeByte(qos);
		}
		
		return buf;
	}
	
	 static ByteBuf encodePublishMessage(
		MqttPublishMsg message) {
		MqttFixedHeader mqttFixedHeader = message.fixedHeader();
		MqttPublishVariableHeader variableHeader = message.variableHeader();
		//ByteBuf payload = message.payload().duplicate();
		
		string topicName = variableHeader.topicName();
		ubyte[] topicNameBytes = cast(ubyte[])(topicName);

		int variableHeaderBufferSize = 2 + cast(int)topicNameBytes.length +
			(to!(int)(mqttFixedHeader.qosLevel())> 0 ? 2 : 0);
		int payloadBufferSize = cast(int)message.content().length;
		int variablePartSize = variableHeaderBufferSize + payloadBufferSize;
		int fixedHeaderBufferSize = 1 + getVariableLengthInt(variablePartSize);
		
		ByteBuf buf = new ByteBuf;
		buf.writeByte(getFixedHeaderByte1(mqttFixedHeader));
		writeVariableLengthInt(buf, variablePartSize);
		buf.writeShort(cast(int)topicNameBytes.length);
		buf.writeBytes(topicNameBytes);
		if (to!(int)(mqttFixedHeader.qosLevel()) > 0) {
			buf.writeShort(variableHeader.messageId());
		}
		buf.writeBytes(message.content());
		
		return buf;
	}
	
	 static ByteBuf encodeMessageWithOnlySingleByteFixedHeaderAndMessageId(
		MqttMsg message) {
		MqttFixedHeader mqttFixedHeader = message.fixedHeader();
		MqttMsgIdVariableHeader variableHeader = cast(MqttMsgIdVariableHeader) message.variableHeader();
		int msgId = variableHeader.messageId();

		int variableHeaderBufferSize = 2; // variable part only has a message id
		int fixedHeaderBufferSize = 1 + getVariableLengthInt(variableHeaderBufferSize);
		ByteBuf buf =new ByteBuf;
		buf.writeByte(getFixedHeaderByte1(mqttFixedHeader));
		writeVariableLengthInt(buf, variableHeaderBufferSize);
		buf.writeShort(msgId);
		
		return buf;
	}
	
	 static ByteBuf encodeMessageWithOnlySingleByteFixedHeader(
		MqttMsg message) {
		MqttFixedHeader mqttFixedHeader = message.fixedHeader();
		ByteBuf buf = new ByteBuf;
		buf.writeByte(getFixedHeaderByte1(mqttFixedHeader));
		buf.writeByte(0);
		
		return buf;
	}
	
	 static int getFixedHeaderByte1(MqttFixedHeader header) {
		int ret = 0;
		int va = to!(int)(header.messageType());
		ret |= va<< 4;
		if (header.isDup()) {
			ret |= 0x08;
		}
		int hv = to!(int)(header.qosLevel());
		ret |=  hv<< 1;
		if (header.isRetain()) {
			ret |= 0x01;
		}
		return ret;
	}

	 static void writeVariableLengthInt(ref ByteBuf buf, int num) {
		do {
			int digit = num % 128;
			num /= 128;
			if (num > 0) {
				digit |= 0x80;
			}
			buf.writeByte(digit);
		} while (num > 0);
	}
	
	 static int getVariableLengthInt(int num) {
		int count = 0;
		do {
			num /= 128;
			count++;
		} while (num > 0);
		return count;
	}
	
//	 static byte[] encodeStringUtf8(String s) {
//		return s.getBytes(CharsetUtil.UTF_8);
//	}
}

