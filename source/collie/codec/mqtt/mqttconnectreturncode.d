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
module collie.codec.mqtt.mqttconnectreturncode;

enum MqttConnectReturnCode : ubyte
{
	CONNECTION_ACCEPTED =  0x00,
	CONNECTION_REFUSED_UNACCEPTABLE_PROTOCOL_VERSION = 0X01,
	CONNECTION_REFUSED_IDENTIFIER_REJECTED = 0x02,
	CONNECTION_REFUSED_SERVER_UNAVAILABLE = 0x03,
	CONNECTION_REFUSED_BAD_USER_NAME_OR_PASSWORD = 0x04,
	CONNECTION_REFUSED_NOT_AUTHORIZED = 0x05,
}

