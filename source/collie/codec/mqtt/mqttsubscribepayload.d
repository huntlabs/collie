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
module collie.codec.mqtt.mqttsubscribepayload;

import collie.codec.mqtt.mqtttopicsubscription;

class MqttSubscribePayload 
{
public:
	this(MqttTopicSubscription[] topicSubscriptions) {
		this._topicSubscriptions = topicSubscriptions;
	}
	
	MqttTopicSubscription[] topicSubscriptions() {
		return _topicSubscriptions;
	}

	override
	 string toString() {
		return "";
	}

private:
	MqttTopicSubscription[] _topicSubscriptions;
}

