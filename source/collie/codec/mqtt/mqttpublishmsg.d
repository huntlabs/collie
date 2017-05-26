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
module collie.codec.mqtt.mqttpublishmsg;

import std.conv;
import collie.codec.mqtt.mqttmsg;
import collie.codec.mqtt.mqttfixedheader;
import collie.codec.mqtt.mqttpublishvariableheader;
import collie.codec.mqtt.mqttpublishpayload;

class MqttPublishMsg : MqttMsg
{
public:
	 this(
		MqttFixedHeader mqttFixedHeader,
		MqttPublishVariableHeader variableHeader,
		MqttPublishPayload payload) {
		super(mqttFixedHeader, variableHeader, payload);
	}
	
	override
	 MqttPublishVariableHeader variableHeader() {
		return cast(MqttPublishVariableHeader) super.variableHeader();
	}
	

	override
	public MqttPublishPayload payload() {
		return cast(MqttPublishPayload) super.payload();
	}


	 ubyte[] content() {
		MqttPublishPayload pl = cast(MqttPublishPayload) super.payload();
		ubyte[] data = pl.publishData();
		if (data.length <= 0) {
			throw new Exception("publish payload is empty!");
		}
		return data;
	}


//	 MqttPublishMessage copy() {
//		return replace(content().dup);
//	}
//	
//
//	 MqttPublishMessage duplicate() {
//		return replace(content().dup);
//	}
//	
//
//	 MqttPublishMessage retainedDuplicate() {
//		return replace(content().dup);
//	}
//
//	 MqttPublishMessage replace(ubyte[] content) {
//		return  this(fixedHeader(), variableHeader(), content);
//	}

//	int refCnt() {
//		return content().refCnt();
//	}
	

//	 MqttPublishMessage retain() {
//		content().retain();
//		return this;
//	}
	
//	@Override
//	public MqttPublishMessage retain(int increment) {
//		content().retain(increment);
//		return this;
//	}
//	
//	@Override
//	public MqttPublishMessage touch() {
//		content().touch();
//		return this;
//	}
//	
//	@Override
//	public MqttPublishMessage touch(Object hint) {
//		content().touch(hint);
//		return this;
//	}
//	
//	@Override
//	public boolean release() {
//		return content().release();
//	}
//	
//	@Override
//	public boolean release(int decrement) {
//		return content().release(decrement);
//	}
}

