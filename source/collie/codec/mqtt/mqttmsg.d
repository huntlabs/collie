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
module collie.codec.mqtt.mqttmsg;

import collie.codec.mqtt.mqttfixedheader;

class MqttMsg 
{
public:	
   this(MqttFixedHeader mqttFixedHeader) {
		this(mqttFixedHeader, null, null);
	}
	
	this(MqttFixedHeader mqttFixedHeader, Object variableHeader) {
		this(mqttFixedHeader, variableHeader, null);
	}
	
	this(MqttFixedHeader mqttFixedHeader, Object variableHeader, Object payload) {
		this(mqttFixedHeader, variableHeader, payload, true);
	}

	this(MqttFixedHeader mqttFixedHeader,
		Object variableHeader,
		Object payload,
		bool decoderResult) {
		this._mqttFixedHeader = mqttFixedHeader;
		this._variableHeader = variableHeader;
		this._payload = payload;
		this._decoderResult = decoderResult;
	}
	
	 MqttFixedHeader fixedHeader() {
		return _mqttFixedHeader;
	}
	
	 Object variableHeader() {
		return _variableHeader;
	}
	
	 Object payload() {
		return _payload;
	}

	 bool decoderResult() {
		return _decoderResult;
	}
	

	override string toString() {
		return "";
	}

private:
	  MqttFixedHeader _mqttFixedHeader;
	  Object _variableHeader;
	  Object _payload;
	  bool _decoderResult;
}

