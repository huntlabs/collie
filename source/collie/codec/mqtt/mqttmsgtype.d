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
module collie.codec.mqtt.mqttmsgtype;



enum MqttMsgType
{
	CONNECT = 1,
	CONNACK = 2,
	PUBLISH = 3,
	PUBACK  = 4,
	PUBREC  = 5,
	PUBREL  = 6,
	PUBCOMP = 7,
	SUBSCRIBE = 8,
	SUBACK  = 9,
	UNSUBSCRIBE = 10,
	UNSUBACK = 11,
	PINGREQ = 12,
	PINGRESP = 13,
	DISCONNECT = 14,
	UNKNOWN   = 15,
}