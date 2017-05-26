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
module collie.codec.mqtt.mqttconnackmessage;

import collie.codec.mqtt.mqttmsg;
import collie.codec.mqtt.mqttfixedheader;
import collie.codec.mqtt.mqttconnackvariableheader;

class MqttConnAckMessage : MqttMsg
{
public:
	 this(MqttFixedHeader mqttFixedHeader, MqttConnAckVariableHeader variableHeader) {
		super(mqttFixedHeader, variableHeader);
	}

	override
	 MqttConnAckVariableHeader variableHeader() {
		return cast(MqttConnAckVariableHeader) super.variableHeader();
	}
}

