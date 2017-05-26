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
module collie.codec.mqtt.mqttpublishvariableheader;

class MqttPublishVariableHeader 
{

public:
	 this(string topicName, int messageId) {
		this._topicName = topicName;
		this._messageId = messageId;
	}
	
	 string topicName() {
		return _topicName;
	}
	
	 int messageId() {
		return _messageId;
	}

	override
	 string toString() {
		return "";
	}
private:
	  string _topicName;
	  int _messageId;
}

