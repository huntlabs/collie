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
module collie.codec.mqtt.mqttfixedheader;

import collie.codec.mqtt.mqttmsgtype;
import collie.codec.mqtt.mqttqos;

final class MqttFixedHeader
{
public:
	this(MqttMsgType messageType,
		bool isDup,
		MqttQoS qosLevel,
		bool isRetain,
		int remainingLength)
	{
		// Constructor code
		this._messageType = messageType;
		this._isDup = isDup;
		this._qosLevel = qosLevel;
		this._isRetain = isRetain;
		this._remainingLength = remainingLength;
	}

	
	 MqttMsgType messageType() {
		return _messageType;
	}

	 bool isDup() {
		return _isDup;
	}

	 MqttQoS qosLevel() {
		return _qosLevel;
	}

	 bool isRetain() {
		return _isRetain;
	}
	
	 int remainingLength() {
		return _remainingLength;
	}
	

	override string toString() {
		return "";
	}

private:
	MqttMsgType _messageType;
	bool _isDup;
	MqttQoS _qosLevel;
	bool _isRetain;
	int _remainingLength;
}

