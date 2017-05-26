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
module collie.codec.mqtt.mqttqos;

enum MqttQoS
{
	AT_MOST_ONCE = 0,
	AT_LEAST_ONCE = 1,
	EXACTLY_ONCE = 2,
	FAILURE = 0x80,
}

