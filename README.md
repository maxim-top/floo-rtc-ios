# 蓝莺IM SDK，iOS本地库

蓝莺IM，是由[美信拓扑](https://www.maximtop.com/)团队研发的新一代即时通讯云服务，SDK设计简单集成方便，服务采用云原生技术和多云架构，私有云也可按月付费。

蓝莺IM RTC SDK，则是在蓝莺IM SDK的基础上，以IM作为信令通道，提供了实时音视频功能，可以帮助用户快速将实时音视频功能集成到App中。目前的版本提供一对一的视频通话和语音通话功能。

[![Scc Count Badge](https://sloc.xyz/github/maxim-top/floo-rtc-ios/?category=total&avg-wage=1)](https://github.com/maxim-top/floo-rtc-ios/) [![Scc Count Badge](https://sloc.xyz/github/maxim-top/floo-rtc-ios/?category=code&avg-wage=1)](https://github.com/maxim-top/floo-rtc-ios/)

## 介绍

整个SDK只需使用一个公开的类：RTCEngineManager，通过RTCEngineManager获取到BMXRTCEngine，进而完成RTC相关业务功能。其它相关的类还有BMXRTCEngineListener、BMXRTCService和BMXRTCServiceListener。

其中：
BMXRTCEngine用于提供RTC相关业务功能，比如进入房间、退出房间、发布流、订阅流等；
BMXRTCEngineListener用于接收RTC相关业务事件，比如发布流成功、退出房间成功等；
BMXRTCService用于发送RTC基本类型的消息，有发起呼叫、接听呼叫、结束通话；
BMXRTCServiceListener用于接收RTC基本类型的消息。如果您还有其它类型的自定义消息，可以通过floo-android提供的消息机制创建自定义消息，发送和接收。

## 开发

蓝莺 IM RTC SDK 目前实现了一对一的视频和语音通话功能。集成方式有两种：可以通过 CocoaPods 自动集成我们的 floo-rtc-ios，也可以通过手动下载 floo-rtc-ios.framework, 手动添加到项目中。

### 方式一：自动集成/CocoaPods

提示：如果未安装cocoapods，请参照 [CocoaPods安装](https://cocoapods.org)

1.  在 Podfile 文件中加入 floo-rtc-ios :

    ```
    pod 'floo-rtc-ios'
    ```
2.  执行安装 ，命令如下

    ```
    pod install
    ```

    提示：如果无法安装 SDK 最新版本，运行以下命令更新本地的 CocoaPods 仓库列表

    ```
    pod repo update
    ```

### 方式二：手动集成

[下载 floo-rtc-ios.framework](https://package.lanyingim.com/floo-rtc-ios.zip) , 然后将文件引用到您的项目中。

### 添加WebRTC依赖

在 Podfile文件中加入

```
  pod 'GoogleWebRTC', '~> 1.1'
```

### 创建用户界面

```
//创建对方画面视图
#if defined(RTC_SUPPORTS_METAL)
            _remoteVideoView = [[RTCMTLVideoView alloc] initWithFrame:CGRectZero];
#else
            RTCEAGLVideoView *remoteView = [[RTCEAGLVideoView alloc] initWithFrame:CGRectZero];
            _remoteVideoView = remoteView;
#endif            
            [self addSubview:_remoteVideoView];
//创建本地画面视图
            _localVideoView = [[UIView alloc] initWithFrame:CGRectZero];
            [self addSubview:_localVideoView];
```

### 音视频通话业务逻辑
1. 导入RTCEngineManager

```
    #import <floo-rtc-ios/RTCEngineManager.h>
```

2. 添加事件监听

在类接口声明中添加协议：BMXRTCEngineProtocol：
```
@interface CallViewController () < BMXRTCEngineProtocol >
```

添加BMXRTCEngineProtocol事件监听：
```
    [[RTCEngineManager engineWithType:kMaxEngine] addDelegate:self];
```

3. 加入房间

```
    //设置视频分辨率
    BMXVideoConfig *videoConfig = [[BMXVideoConfig alloc] init];
    [videoConfig setWidth:720];
    [videoConfig setHeight:1280];
    [[RTCEngineManager engineWithType:kMaxEngine] setVideoProfile:videoConfig];
    //设置用户ID、pin密码和房间ID
    BMXRoomAuth *auth = [[BMXRoomAuth alloc] init];
    [auth setMUserId:userId];
    [auth setMToken:pin]; //房间pin密码，建议随机生成高强度密码
    [auth setMRoomId:roomId]; //主叫方无须设置roomId，房间创建成功事件会返回系统分配的roomId；被叫方需要设置与主叫方一样的roomId
    [[RTCEngineManager engineWithType:kMaxEngine] joinRoomWithAuth:auth];
```

4. 加入房间结果回调

```
- (void)onJoinRoomWithInfo:(NSString*)info roomId:(long long)roomId error:(BMXErrorCode)error{
    //保存房间ID
    _roomId = roomId;
    if (error == BMXErrorCode_NoError) {
        //发布本地音视频流
        [[RTCEngineManager engineWithType:kMaxEngine] publishWithType:BMXVideoMediaType_Camera hasVideo:_hasVideo hasAudio:YES];
        //主叫方开始发送呼叫的消息
        if (_isCaller) {
            [self sendCallMessage];
        }
    }
}
```

5. 收到对方视频流

```
- (void)onSubscribeWithStream:(BMXStream*)stream info:(NSString*)info error:(BMXErrorCode)error{
    if (error != BMXErrorCode_NoError) {
        return;
    }
    BOOL hasVideo = [stream getMEnableVideo];
    if (hasVideo) {
        BMXVideoCanvas *canvas = [[BMXVideoCanvas alloc] init];
        [canvas setMUserId:[stream getMUserId]];
        //设置用于渲染对方视频画面的视图
        [canvas setMView:(void*)_videoCallView.remoteVideoView];
        //渲染对方视频画面
        [[RTCEngineManager engineWithType:kMaxEngine] startRemoteViewWithCanvas:canvas];
    }
}
```

6. 挂断通话

```
- (void)hangupByMe:(BOOL)byMe{
    //主动挂断一方需要通知对方挂断
    if (byMe) {
        [self sendHangupMessage];
    }
    //离开房间
    [[RTCEngineManager engineWithType:kMaxEngine] leaveRoom];
    //移除监听
    [[RTCEngineManager engineWithType:kMaxEngine] removeDelegate:self];
}
```

### 使用rtcService实现音视频通话信令

1. 添加事件监听

在类接口声明中添加协议：BMXRTCServiceProtocol：
```
@interface CallViewController () < BMXRTCEngineProtocol, BMXRTCServiceProtocol >
```

添加BMXChatServiceProtocol和BMXRTCServiceProtocol事件监听：
```
    [[RTCEngineManager engineWithType:kMaxEngine] addDelegate:self];
    [[[BMXClient sharedClient] rtcService] addDelegate:self];
```

2. 发送呼叫消息

```
- (void)sendCallMessage{
    //封装呼叫消息config
    BMXMessageConfig *config = [BMXMessageConfig createMessageConfigWithMentionAll: NO];
    [config setRTCCallInfo:_hasVideo?BMXMessageConfig_RTCCallType_VideoCall:BMXMessageConfig_RTCCallType_AudioCall roomId:_roomId initiator:_myId roomType:BMXMessageConfig_RTCRoomType_Broadcast pin:_pin];
    _callId = config.getRTCCallId;

    BMXMessage *msg = [BMXMessage createRTCMessageWithFrom:_myId to:_peerId type:BMXMessage_MessageType_Single conversationId:_peerId content:@"new call"];
    msg.config = config;
    //设置消息扩展信息，离线时服务端会发送推送
    [msg setExtension:@"{\"rtc\":\"call\"}"];
    [[[BMXClient sharedClient] rtcService] sendRTCMessageWithMsg:msg completion:^(BMXError *aError) {
    }];
}
```

3. 发送接听消息

```
- (void)sendPickupMessage{
    //封装接听消息config
    BMXMessageConfig *config = [BMXMessageConfig createMessageConfigWithMentionAll: NO];
    [config setRTCPickupInfo:_callId];
    BMXMessage *msg = [BMXMessage createRTCMessageWithFrom:_myId to:_peerId type:BMXMessage_MessageType_Single conversationId:_peerId content:@""];
    msg.config = config;
    [[[BMXClient sharedClient] rtcService] sendRTCMessageWithMsg:msg completion:^(BMXError *aError) {
    }];
    //发送消息已读回执，确认主叫端呼叫的那条消息
    [self ackMessageWithMessageId:_messageId];
}

- (void)ackMessageWithMessageId:(long long)messageId{
    BMXMessage *msg = [[[BMXClient sharedClient] chatService] getMessage:messageId];
    if (msg) {
        [[[BMXClient sharedClient] chatService] ackMessageWithMsg:msg];
    }
}

```

4. 发送挂断消息

```
- (void)sendHangupMessage{
    //封装挂断消息config
    BMXMessageConfig *config = [BMXMessageConfig createMessageConfigWithMentionAll: NO];
    if (_callId) {
        [config setRTCHangupInfo:_callId];
        _callId = nil;
    }
    //设置消息内容，用于界面展示通话时长、已取消、已拒绝、未接听等
    NSTimeInterval duration = 0.0;
    NSString *content = @"canceled"; //Caller canceled
    if (!_isCaller) {
        content = @"rejected"; //Callee rejected
    }else{
        if (_ringTimes == 0) { //Callee not responding
            content = @"timeout";
        }
    }
    if (_pickupTimestamp > 1.0) {
        duration = [self getTimeStamp] - _pickupTimestamp;
    }
    if (duration > 1.0) {
        content = [NSString stringWithFormat:@"%.0f", duration];
    }
    BMXMessage *msg = [BMXMessage createRTCMessageWithFrom:_myId to:_peerId type:BMXMessage_MessageType_Single conversationId:_peerId content:content];
    msg.config = config;
    [[[BMXClient sharedClient] rtcService] sendRTCMessageWithMsg:msg completion:^(BMXError *aError) {
        //同步挂断消息，用于实时更新会话界面的通话历史记录
        NSNotification *noti = [NSNotification notificationWithName:@"call" object:self userInfo:@{@"event":@"hangup"}];
        //发送通知
        [[NSNotificationCenter defaultCenter]postNotification:noti];
    }];
}

在会话界面处理挂断消息：
- (void)receiveNoti:(NSNotification*)noti
{
    NSString *event = noti.userInfo[@"event"];
    if ([event isEqualToString:@"hangup"]) {
        [[[BMXClient sharedClient] chatService] retrieveHistoryMessagesWithConversation:self.conversation refMsgId:0 size:1 completion:^(BMXMessageList *messageList, BMXError *error) {
            //会话界面的通话历史记录
            //...
       }];
    }
}

```

5. 挂断通话

```
- (void)hangupByMe:(BOOL)byMe{
    //主动挂断一方需要通知对方挂断
    if (byMe) {
        [self sendHangupMessage];
    }
    //离开房间
    [[RTCEngineManager engineWithType:kMaxEngine] leaveRoom];
    //移除监听
    [[RTCEngineManager engineWithType:kMaxEngine] removeDelegate:self];
    [[[BMXClient sharedClient] rtcService] removeDelegate:self];
}
```

6. 被叫方处理接收到的呼叫消息

```
#pragma mark - BMXRTCServiceProtocol
- (void)onRTCCallMessageReceiveWithMsg:(BMXMessage*)message {
    //解析呼叫消息config字段
    long long roomId = message.config.getRTCRoomId;
    long long myId = [self.account.usedId longLongValue];
    long long peerId = message.config.getRTCInitiator;
    if (myId == peerId){
        return;
    }
    NSString *pin = message.config.getRTCPin;
    NSString *callId = message.config.getRTCCallId;
    BOOL hasVideo = message.config.getRTCCallType == 1;
    //打开呼叫界面
    //...
}
```

7. 处理接收到的挂断消息

```
- (void)onRTCHangupMessageReceiveWithMsg:(BMXMessage*)msg {
    //离开房间并确认消息为已读
}
```

8. 处理接收到的接听消息
```
- (void)onRTCPickupMessageReceiveWithMsg:(BMXMessage*)msg{
    //如果消息是我的其它终端发送的
    if ([msg.config.getRTCCallId isEqualToString: _callId] && msg.fromId == _myId) {
        //关闭呼叫界面并确认消息已读
    }
}
```

快速集成文档参考[蓝莺快速集成指南iOS版](https://docs.lanyingim.com/quick-start/floo-ios-quick-start.html)，
详细文档可参考[floo-ios reference](https://docs.lanyingim.com/reference/floo-ios.html)

祝玩得开心😊
