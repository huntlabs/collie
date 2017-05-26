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
module collie.codec.mqtt.mqttunsubscribemsg;

import collie.codec.mqtt.mqttmsg;
import collie.codec.mqtt.mqttfixedheader;
import collie.codec.mqtt.mqttmsgidvariableheader;
import collie.codec.mqtt.mqttunsubscribepayload;

class MqttUnsubscribeMsg : MqttMsg
{
	public this(
		MqttFixedHeader mqttFixedHeader,
		MqttMsgIdVariableHeader variableHeader,
		MqttUnsubscribePayload payload) {
		super(mqttFixedHeader, variableHeader, payload);
	}
	
	override
	 MqttMsgIdVariableHeader variableHeader() {
		return cast(MqttMsgIdVariableHeader) super.variableHeader();
	}
	
	override
	 MqttUnsubscribePayload payload() {
		return cast(MqttUnsubscribePayload) super.payload();
	}
}

