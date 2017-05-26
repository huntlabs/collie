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
module collie.codec.mqtt.mqttconnackvariableheader;

import collie.codec.mqtt.mqttconnectreturncode;

class MqttConnAckVariableHeader 
{
public:
	 this(MqttConnectReturnCode connectReturnCode, bool sessionPresent) {
		this._connectReturnCode = connectReturnCode;
		this._sessionPresent = sessionPresent;
	}
	
	 MqttConnectReturnCode connectReturnCode() {
		return _connectReturnCode;
	}

	 bool isSessionPresent() {
		return _sessionPresent;
	}
	
	override
	 string toString() {
		return "";
	}

private:
	  MqttConnectReturnCode _connectReturnCode;
	
	  bool _sessionPresent;
}

