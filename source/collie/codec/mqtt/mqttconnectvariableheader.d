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
module collie.codec.mqtt.mqttconnectvariableheader;
import collie.codec.mqtt.mqttversion;

class MqttConnectVariableHeader 
{

public:
	this(
		string name,
		int mqtt_version,
		bool hasUserName,
		bool hasPassword,
		bool isWillRetain,
		int willQos,
		bool isWillFlag,
		bool isCleanSession,
		int keepAliveTimeSeconds) {
		this._name = name;
		this._version = mqtt_version;
		this._hasUserName = hasUserName;
		this._hasPassword = hasPassword;
		this._isWillRetain = isWillRetain;
		this._willQos = willQos;
		this._isWillFlag = isWillFlag;
		this._isCleanSession = isCleanSession;
		this._keepAliveTimeSeconds = keepAliveTimeSeconds;
	}

	 string name() {
		return _name;
	}
	
	int mqtt_version() {
		return _version;
	}
	
	 bool hasUserName() {
		return _hasUserName;
	}
	
	 bool hasPassword() {
		return _hasPassword;
	}

	 bool isWillRetain() {
		return _isWillRetain;
	}
	
	 int willQos() {
		return _willQos;
	}

	 bool isWillFlag() {
		return _isWillFlag;
	}

	 bool isCleanSession() {
		return _isCleanSession;
	}
	
	 int keepAliveTimeSeconds() {
		return _keepAliveTimeSeconds;
	}

	override
	 string toString() {
		return "";
	}

private:
	  string _name;
	  int _version;
	  bool _hasUserName;
	  bool _hasPassword;
	  bool _isWillRetain;
	  int _willQos;
	  bool _isWillFlag;
	  bool _isCleanSession;
	  int _keepAliveTimeSeconds;
}

