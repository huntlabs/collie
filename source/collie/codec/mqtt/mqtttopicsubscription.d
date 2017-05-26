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
module collie.codec.mqtt.mqtttopicsubscription;

import collie.codec.mqtt.mqttqos;

class MqttTopicSubscription 
{
public:
	 this(string topicFilter, MqttQoS qualityOfService) {
		this._topicFilter = topicFilter;
		this._qualityOfService = qualityOfService;
	}
	
	 string topicName() {
		return _topicFilter;
	}
	
	 MqttQoS qualityOfService() {
		return _qualityOfService;
	}
	
	override
	 string toString() {
		return "";
	}
private:
	  string _topicFilter;
	  MqttQoS _qualityOfService;
}

