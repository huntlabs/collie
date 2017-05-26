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
module collie.codec.mqtt.mqttmsgidvariableheader;

class MqttMsgIdVariableHeader 
{
public:
	static MqttMsgIdVariableHeader from(int messageId) {
		if (messageId < 1 || messageId > 0xffff) {

			throw new Exception("messageId: " ~ messageId.stringof ~ " (expected: 1 ~ 65535)");
		}
		return  new MqttMsgIdVariableHeader(messageId);
	}
	
	int messageId() {
		return _messageId;
	}

	override string toString() {
		return "";
	}
	
private:	
	this(int messageId) {
		this._messageId = messageId;
	}
	
	
private:
	int _messageId;
}

