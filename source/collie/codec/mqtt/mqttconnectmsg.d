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
module collie.codec.mqtt.mqttconnectmsg;

import collie.codec.mqtt.mqttmsg;
import collie.codec.mqtt.mqttfixedheader;
import collie.codec.mqtt.mqttconnectpayload;
import collie.codec.mqtt.mqttconnectvariableheader;

class MqttConnectMsg : MqttMsg
{
public:
	this(
		MqttFixedHeader mqttFixedHeader,
		MqttConnectVariableHeader variableHeader,
		MqttConnectPayload payload) {
		super(mqttFixedHeader, variableHeader, payload);
	}
	
	override
	 MqttConnectVariableHeader variableHeader() {
		return cast(MqttConnectVariableHeader) super.variableHeader();
	}
	
	override
	 MqttConnectPayload payload() {
		return cast(MqttConnectPayload) super.payload();
	}
}

