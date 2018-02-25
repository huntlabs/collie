/*
 * Collie - An asynchronous event-driven network framework using Dlang development
 *
 * Copyright (C) 2015-2016  Shanghai Putao Technology Co., Ltd 
 *
 * Developer: putao's Dlang team
 *
 * Licensed under the Apache-2.0 License.
 *
 */
module app;

import core.thread;

import std.datetime;
import std.stdio;
import std.functional;
import std.experimental.logger;

import collie.net;
import collie.channel;
import collie.bootstrap.server;

import collie.codec.mqtt;
import std.conv;

import collie.net.common;
import collie.net.transport;
import collie.channel.pipeline;
import collie.channel.handlercontext;


alias Pipeline!(ubyte[], ubyte[]) EchoPipeline;

ServerBootstrap!EchoPipeline ser;

class MqttServerHandler : MqttDecoder//HandlerAdapter!(MqttMsg[], ubyte[])
{
public:
	override void read(Context ctx, ubyte[] msg){
   
		bool success = true;
		MqttMsg[] mqs;
		success = decode(ctx, msg, mqs);
		if (!success)
		{
			writeln(" decoder false");
			return;
		}

		switch(mqs[0].fixedHeader().messageType())
		{
			case MqttMsgType.CONNECT:
				testConnectMessageForMqtt31Or311(mqs[0]);
				break;
				
			case MqttMsgType.CONNACK:
				testConnAckMessage(mqs[0]);
				break;
				
			case MqttMsgType.SUBSCRIBE:
				testSubscribeMessage(mqs[0]);
				break;
			case MqttMsgType.UNSUBSCRIBE:
				testUnSubscribeMessage(mqs[0]);
				break;
			case MqttMsgType.SUBACK:
				testSubAckMessage(mqs[0]);
				break;
			case MqttMsgType.UNSUBACK:
				testUnsubAckMessage(mqs[0]);
				break;
			case MqttMsgType.PUBACK:
				testPubAckMessage(mqs[0]);
				break;
			case MqttMsgType.PUBREC:
				testPubRecMessage(mqs[0]);
				break;
			case MqttMsgType.PUBCOMP:
				testPubCompMessage(mqs[0]);
				break;
			case MqttMsgType.PUBREL:
				testPubRelMessage(mqs[0]);
				break;
				
			case MqttMsgType.PUBLISH:
				testPublishMessage(mqs[0]);
				break;
				
			case MqttMsgType.PINGREQ:
				testPingReqMessage(mqs[0]);
				break;
			case MqttMsgType.PINGRESP:
				testPingRespMessage(mqs[0]);
				break;
			case MqttMsgType.DISCONNECT:
				testDisconnectMessage(mqs[0]);
				break;
				// Empty variable header
				
			default:

				break;
		}
    }

//    void callBack(ubyte[] data, size_t len){
//        writeln("writed data : ", cast(string) data, "   the length is ", len);
//    }
//
//    override void timeOut(Context ctx){
//        writeln("Sever beat time Out!");
//    }
}

shared class EchoPipelineFactory : PipelineFactory!EchoPipeline
{
public:
    override EchoPipeline newPipeline(TcpStream sock){
        auto pipeline = EchoPipeline.create();
        pipeline.addBack(new TCPSocketHandler(sock));
        pipeline.addBack(new MqttServerHandler());
        pipeline.finalize();
        return pipeline;
    }
}

void main()
{
    ser = new ServerBootstrap!EchoPipeline();
    ser.childPipeline(new EchoPipelineFactory()).heartbeatTimeOut(360)
        .group(new EventLoopGroup).bind(8094);
    ser.waitForStop();

    writeln("APP Stop!");
}

//mqtt 3.1 or 3.1.1 版本  的测试连接报文 
void testConnectMessageForMqtt31Or311(MqttMsg mqs)
{
	writeln("---------------testConnectMessageForMqtt31Or311----------------");

	MqttConnectMsg decodedMessage = cast(MqttConnectMsg) mqs;
	writeln("MqttFixedHeader MqttMessageType :  ",decodedMessage.fixedHeader().messageType());
	writeln("MqttFixedHeader Qos :  ",decodedMessage.fixedHeader().qosLevel());
	
	writeln("MqttConnectVariableHeader Name : ", decodedMessage.variableHeader.name());
	writeln(
		"MqttConnectVariableHeader KeepAliveTimeSeconds : ",
		decodedMessage.variableHeader.keepAliveTimeSeconds());
	writeln("MqttConnectVariableHeader Version : ", decodedMessage.variableHeader.mqtt_version());
	writeln("MqttConnectVariableHeader WillQos : ", decodedMessage.variableHeader.willQos());
	
	writeln("MqttConnectVariableHeader HasUserName : ", decodedMessage.variableHeader.hasUserName());
	writeln("MqttConnectVariableHeader HasPassword : ", decodedMessage.variableHeader.hasPassword());
	writeln(
		"MqttConnectVariableHeader IsCleanSession : ",
		decodedMessage.variableHeader.isCleanSession());
	writeln("MqttConnectVariableHeader IsWillFlag : ", decodedMessage.variableHeader.isWillFlag());
	writeln(
		"MqttConnectVariableHeader IsWillRetain : ",
		decodedMessage.variableHeader.isWillRetain());
	
	writeln(
		"MqttConnectPayload ClientIdentifier  ",
		decodedMessage.payload().clientIdentifier());
	writeln("MqttConnectPayload UserName : ", decodedMessage.payload().userName());
	writeln("MqttConnectPayload Password : ", decodedMessage.payload().password());
	writeln("MqttConnectPayload WillMessage : ", decodedMessage.payload().willMessage());
	writeln("MqttConnectPayload WillTopic : ", decodedMessage.payload().willTopic());
	
}


//测试确认连接
void testConnAckMessage(MqttMsg mqs)  {
	writeln("---------------testConnAckMessage----------------");

	
	MqttConnAckMessage decodedMessage = cast(MqttConnAckMessage) mqs;
	writeln("MqttFixedHeader MqttMessageType :  ",decodedMessage.fixedHeader().messageType());
	writeln("MqttFixedHeader Qos :  ",decodedMessage.fixedHeader().qosLevel());
	
	writeln(
		"MqttConnAckVariableHeader MqttConnectReturnCode : ",
		decodedMessage.variableHeader().connectReturnCode());
}


//发布消息
void testPublishMessage(MqttMsg mqs)   {
	writeln("---------------testPublishMessage----------------");

	MqttPublishMsg decodedMessage = cast(MqttPublishMsg)mqs;
	
	writeln("MqttFixedHeader MqttMessageType :  ",decodedMessage.fixedHeader().messageType());
	writeln("MqttFixedHeader Qos :  ",decodedMessage.fixedHeader().qosLevel());
	
	writeln("MqttPublishVariableHeader TopicName : ", decodedMessage.variableHeader().topicName());
	writeln("MqttPublishVariableHeader MessageId : ", decodedMessage.variableHeader().messageId());
	
	writeln("PublishPayload : ", cast(string)decodedMessage.payload().publishData());
}


void testMessageWithOnlyFixedHeaderAndMessageIdVariableHeader(MqttMsgType messageType,MqttMsg mqs)
{

	MqttMsg decodedMessage = cast(MqttMsg) mqs;
	writeln("MqttFixedHeader MqttMessageType :  ",decodedMessage.fixedHeader().messageType());
	writeln("MqttFixedHeader Qos :  ",decodedMessage.fixedHeader().qosLevel());
	
	writeln("MqttMessageIdVariableHeader MessageId : ", (cast(MqttMsgIdVariableHeader)(decodedMessage.variableHeader())).messageId());
}


//发布确认
void testPubAckMessage(MqttMsg mqs)   {
	writeln("---------------testPubAckMessage----------------");
	testMessageWithOnlyFixedHeaderAndMessageIdVariableHeader(MqttMsgType.PUBACK,mqs);
}


//发布收到
void testPubRecMessage(MqttMsg mqs)   {
	writeln("---------------testPubRecMessage----------------");
	testMessageWithOnlyFixedHeaderAndMessageIdVariableHeader(MqttMsgType.PUBREC,mqs);
}

//发布释放
void testPubRelMessage(MqttMsg mqs)   {
	writeln("---------------testPubRelMessage----------------");
	testMessageWithOnlyFixedHeaderAndMessageIdVariableHeader(MqttMsgType.PUBREL,mqs);
}

//发布完成
void testPubCompMessage(MqttMsg mqs)   {
	writeln("---------------testPubCompMessage----------------");
	testMessageWithOnlyFixedHeaderAndMessageIdVariableHeader(MqttMsgType.PUBCOMP,mqs);
}

//订阅主题
void testSubscribeMessage(MqttMsg mqs)   {
	writeln("---------------testSubscribeMessage----------------");

	
	MqttSubscribeMsg decodedMessage = cast(MqttSubscribeMsg) mqs;
	writeln("MqttFixedHeader MqttMessageType :  ",decodedMessage.fixedHeader().messageType());
	writeln("MqttFixedHeader Qos :  ",decodedMessage.fixedHeader().qosLevel());
	
	writeln("MqttMessageIdVariableHeader MessageId : ", decodedMessage.variableHeader().messageId());
	
	MqttTopicSubscription[] expectedTopicSubscriptions = decodedMessage.payload().topicSubscriptions();

	
	writeln(
		"MqttSubscribePayload TopicSubscriptionList size : ",
		expectedTopicSubscriptions.length);
	for (int i = 0; i < expectedTopicSubscriptions.length; i++) {
		writeln("MqttTopicSubscription TopicName : ", expectedTopicSubscriptions[i].topicName());
		writeln(
			"MqttTopicSubscription Qos : ",
			expectedTopicSubscriptions[i].qualityOfService());
	}
}

//订阅确认
void testSubAckMessage(MqttMsg mqs)   {
	writeln("---------------testSubAckMessage----------------");

	MqttSubAckMsg decodedMessage = cast(MqttSubAckMsg)mqs;
	writeln("MqttFixedHeader MqttMessageType :  ",decodedMessage.fixedHeader().messageType());
	writeln("MqttFixedHeader Qos :  ",decodedMessage.fixedHeader().qosLevel());
	
	writeln("MqttMessageIdVariableHeader MessageId : ", decodedMessage.variableHeader().messageId());
	
	writeln(
		"MqttSubAckPayload GrantedQosLevels : ",
		decodedMessage.payload().grantedQoSLevels());
}


//取消订阅
void testUnSubscribeMessage(MqttMsg mqs)   {
	writeln("---------------testUnSubscribeMessage----------------");

	MqttUnsubscribeMsg decodedMessage = cast(MqttUnsubscribeMsg) mqs;
	writeln("MqttFixedHeader MqttMessageType :  ",decodedMessage.fixedHeader().messageType());
	writeln("MqttFixedHeader Qos :  ",decodedMessage.fixedHeader().qosLevel());
	
	writeln("MqttMessageIdVariableHeader MessageId : ", decodedMessage.variableHeader().messageId());
	
	writeln(
		"MqttUnsubscribePayload TopicList : ",
		decodedMessage.payload().topics());
}


//取消订阅确认
void testUnsubAckMessage(MqttMsg mqs)   {
	writeln("---------------testUnsubAckMessage----------------");
	testMessageWithOnlyFixedHeaderAndMessageIdVariableHeader(MqttMsgType.UNSUBACK,mqs);
}

//心跳请求
void testPingReqMessage(MqttMsg mqs)   {
	writeln("---------------testPingReqMessage----------------");
	testMessageWithOnlyFixedHeader(MqttMsgType.PINGREQ,mqs);
}

//心跳响应
void testPingRespMessage(MqttMsg mqs)   {
	writeln("---------------testPingRespMessage----------------");
	testMessageWithOnlyFixedHeader(MqttMsgType.PINGRESP,mqs);
}

//断开连接
void testDisconnectMessage(MqttMsg mqs)   {
	writeln("---------------testDisconnectMessage----------------");
	testMessageWithOnlyFixedHeader(MqttMsgType.DISCONNECT,mqs);
}

void testMessageWithOnlyFixedHeader(MqttMsgType messageType,MqttMsg mqs)   {

	MqttMsg decodedMessage = cast(MqttMsg) mqs;
	writeln("MqttFixedHeader MqttMessageType :  ",decodedMessage.fixedHeader().messageType());
	writeln("MqttFixedHeader Qos :  ",decodedMessage.fixedHeader().qosLevel());
}


