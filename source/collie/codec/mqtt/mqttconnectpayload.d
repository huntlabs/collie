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

module collie.codec.mqtt.mqttconnectpayload;

class MqttConnectPayload
{

public:	
	this(string clientIdentifier,
		string willTopic,
		string willMessage,
		string userName,
		string password) {
		this._clientIdentifier = clientIdentifier;
		this._willTopic = willTopic;
		this._willMessage = willMessage;
		this._userName = userName;
		this._password = password;
	}

	 string clientIdentifier() {
		return _clientIdentifier;
	}

	 string willTopic() {
		return _willTopic;
	}
	
	 string willMessage() {
		return _willMessage;
	}
	
	 string userName() {
		return _userName;
	}
	
	 string password() {
		return _password;
	}


	override string toString() {
		return "";
	}
private:
	string _clientIdentifier;
	string _willTopic;
	string _willMessage;
	string _userName;
	string _password;
}

