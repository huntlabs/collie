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
module collie.codec.mqtt.mqttcodecutil;

import kiss.logger;
import std.conv;
import std.stdio;
import std.string;
import std.array;
import collie.codec.mqtt.mqttversion;
import collie.codec.mqtt.mqttfixedheader;
import collie.codec.mqtt.mqttmsgtype;
import collie.codec.mqtt.mqttqos;

class MqttCodecUtil
{
	static bool isValidPublishTopicName(string topicName) {
		// publish topic name must not contain any wildcard
		foreach (char c ; TOPIC_WILDCARDS) {
			if (indexOf(topicName,c) >= 0) {
				return false;
			}
		}
		return true;
	}
	
	static bool isValidMessageId(int messageId) {
		return messageId != 0;
	}

	static bool isValidClientId(MqttVersion mqttVersion, string clientId) {
		if (mqttVersion.protocolName() == "MQIsdp") {
			return clientId != null && clientId.length >= MIN_CLIENT_ID_LENGTH &&
				clientId.length <= MAX_CLIENT_ID_LENGTH;
		}
		if (mqttVersion.protocolName() == "MQTT") {
			// In 3.1.3.1 Client Identifier of MQTT 3.1.1 specification, The Server MAY allow ClientId’s
			// that contain more than 23 encoded bytes. And, The Server MAY allow zero-length ClientId.
			return clientId != null;
		}

		logDebug(to!string(mqttVersion) ~ " is unknown mqtt version");
		return false;
	}
	
	static MqttFixedHeader validateFixedHeader(MqttFixedHeader mqttFixedHeader) {
		switch (mqttFixedHeader.messageType()) {
			case MqttMsgType.PUBREL:
			case MqttMsgType.SUBSCRIBE:
			case MqttMsgType.UNSUBSCRIBE:
				if (mqttFixedHeader.qosLevel() != MqttQoS.AT_LEAST_ONCE) {
					
					throw new Exception(to!string(mqttFixedHeader.messageType()) ~ " message must have QoS 1");
				}
				return mqttFixedHeader;
			default:
				return mqttFixedHeader;
		}
	}
	
	static MqttFixedHeader resetUnusedFields(MqttFixedHeader mqttFixedHeader) {
		switch (mqttFixedHeader.messageType()) {
			case MqttMsgType.CONNECT:
			case MqttMsgType.CONNACK:
			case MqttMsgType.PUBACK:
			case MqttMsgType.PUBREC:
			case MqttMsgType.PUBCOMP:
			case MqttMsgType.SUBACK:
			case MqttMsgType.UNSUBACK:
			case MqttMsgType.PINGREQ:
			case MqttMsgType.PINGRESP:
			case MqttMsgType.DISCONNECT:
				if (mqttFixedHeader.isDup() ||
					mqttFixedHeader.qosLevel() != MqttQoS.AT_MOST_ONCE ||
					mqttFixedHeader.isRetain()) {
					return new MqttFixedHeader(
						mqttFixedHeader.messageType(),
						false,
						MqttQoS.AT_MOST_ONCE,
						false,
						mqttFixedHeader.remainingLength());
				}
				return mqttFixedHeader;
			case MqttMsgType.PUBREL:
			case MqttMsgType.SUBSCRIBE:
			case MqttMsgType.UNSUBSCRIBE:
				if (mqttFixedHeader.isRetain()) {
					return new MqttFixedHeader(
						mqttFixedHeader.messageType(),
						mqttFixedHeader.isDup(),
						mqttFixedHeader.qosLevel(),
						false,
						mqttFixedHeader.remainingLength());
				}
				return mqttFixedHeader;
			default:
				return mqttFixedHeader;
		}
	}

private:
	this() { }
private:
	 static  char[] TOPIC_WILDCARDS = array(['#', '+'][]);
	 static  int MIN_CLIENT_ID_LENGTH = 1;
	 static  int MAX_CLIENT_ID_LENGTH = 23;
}

