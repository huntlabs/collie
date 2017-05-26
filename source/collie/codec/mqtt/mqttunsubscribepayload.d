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
module collie.codec.mqtt.mqttunsubscribepayload;

class MqttUnsubscribePayload 
{
public:
	 this(string[] topics) {
		this._topics = topics;
	}
	
	string[] topics() {
		return _topics;
	}
	
	override
	 string toString() {
		return "";
	}
private:
	  string[] _topics;
}

