#import "MaxEngine.h"
#import <WebRTC/RTCSessionDescription.h>
#import "WebRtcClient.h"

@interface MaxEngine () <BMXRTCSignalServiceProtocol, BMXRTCEngineProtocol>
@property(nonatomic, strong) BMXVideoConfig *videoConfig;
@property(nonatomic, assign) long long otherId;
@end

@implementation MaxEngine

+ (instancetype)sharedEngine {
    static MaxEngine* sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[MaxEngine alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init{
    if (self = [super init]) {
        if (!rtcEngineListener) {
            _videoConfig = [[BMXVideoConfig alloc] init];
            [_videoConfig setWidth:480];
            [_videoConfig setHeight:640];
            rtcEngineListener = [[RTCEngineListener alloc] init];
            _pin = @"";
            _bmxRtcSignalService = [[[BMXClient sharedClient] rtcService] getBMXRTCSignalService];
            [_bmxRtcSignalService addDelegate:self];
            _webRtcClient = [[WebRtcClient alloc] init];
            _otherId = 0;
        }
    }
    return self;
}

- (BOOL)isOnCall{
    return _bmxRtcSession != nil;
}

- (long long)otherId{
    return _otherId;
}

- (BMXErrorCode)setVideoProfile:(BMXVideoConfig*)videoConfig{
    _videoConfig = videoConfig;
    [_webRtcClient setVideoWidth:_videoConfig.getWidth height:_videoConfig.getHeight frameRate:_videoConfig.getFrameRate];
    return BMXErrorCode_NoError;
}

- (BMXErrorCode)unPublishWithType:(BMXVideoMediaType)type {
    [_bmxRtcSignalService pubUnPublishWithSession:_bmxRtcSession];
    return BMXErrorCode_NoError;
}

- (BMXErrorCode)joinRoomWithAuth:(BMXRoomAuth *) roomAuth{
    _userId = [roomAuth getMUserId];
    _roomId = [NSString stringWithFormat:@"%lld", [roomAuth getMRoomId]];
    _pin = [roomAuth getMToken];
    [_bmxRtcSignalService createSession];
    return BMXErrorCode_NoError;
}

- (BMXErrorCode)switchCamera{
    [_webRtcClient switchCamera];
    return BMXErrorCode_NoError;
}

- (BMXErrorCode)leaveRoom{
    [self stopPreviewWithCanvas:nil];
    if (_roomId) {
        _userId = -1;
        _roomId = nil;
        
        if (_bmxRtcSession) {
            [_bmxRtcSignalService destroySessionWithSession:_bmxRtcSession];
        }
    }
    return BMXErrorCode_NoError;
}

- (BMXErrorCode)publishWithType:(BMXVideoMediaType)type hasVideo:(BOOL)hasVideo hasAudio:(BOOL)hasAudio{
    __weak typeof(self) weakSelf = self;
    [_webRtcClient createOfferWithRoomId:_roomId hasVideo:hasVideo hasAudio:hasAudio completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
        typeof(self) strongSelf = weakSelf;
        if (strongSelf.bmxRtcSession) {
            BMXRoomSDPInfo * roomSDPInfo = [[BMXRoomSDPInfo alloc] init];
            [roomSDPInfo setSdp:[sdp sdp]];
            [roomSDPInfo setType:BMXRoomSDPType_Offer];
            BMXRoomPubConfigureOptions *options = [[BMXRoomPubConfigureOptions alloc] initWithEnableAudio:hasAudio enableVideo:hasVideo width:strongSelf.videoConfig.getWidth height:strongSelf.videoConfig.getHeight];
            [strongSelf.bmxRtcSignalService pubConfigueWithSession:strongSelf.bmxRtcSession options:options sdp:roomSDPInfo];
        }
    }];
    return BMXErrorCode_NoError;
}

- (BMXErrorCode)startPreviewWithCanvas:(BMXVideoCanvas *)canvas{
    if (canvas) {
        UIView *view = (RTCCameraPreviewView *)[canvas getMView];
        BMXRenderMode mode = [canvas getMRenderMode];
        CGRect rc = [view frame];
        rc.origin = {0,0};
        RTCCameraPreviewView *cpView = [[RTCCameraPreviewView alloc] initWithFrame:rc];
        cpView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        AVCaptureVideoPreviewLayer* previewLayer = (AVCaptureVideoPreviewLayer*) cpView.layer;
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        if (mode == BMXRenderMode_Default) {
            previewLayer.videoGravity = AVLayerVideoGravityResize;
        }else if (mode == BMXRenderMode_Fill){
            previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        }
        [view addSubview:cpView];
        [_webRtcClient startLocalPreview:cpView];
    }
    return BMXErrorCode_NoError;
}

- (BMXErrorCode)subscribeWithStream:(BMXStream*)stream {
    return BMXErrorCode_NoError;
}

- (BMXErrorCode)stopPreviewWithCanvas:(BMXVideoCanvas *)canvas{
    [_webRtcClient stopLocalPreview];
    return BMXErrorCode_NoError;
}

- (BMXErrorCode)muteLocalVideoWithType:(BMXVideoMediaType)type mute:(BOOL)mute{
    [_webRtcClient muteLocalVideoWithType:type mute:mute];
    return BMXErrorCode_NoError;
}

- (BMXErrorCode)muteLocalAudioWithMute:(BOOL)mute{
    [_webRtcClient muteLocalAudioWithMute:mute];
    return BMXErrorCode_NoError;
}

- (BMXErrorCode)startRemoteViewWithCanvas:(BMXVideoCanvas *)canvas{
    [_webRtcClient startRemoteViewWithCanvas:canvas];
    return BMXErrorCode_NoError;
}

- (void)onSessionCreateWithSession:(BMXRTCSession*)session error:(int)error reason:(NSString*)reason{
    if (error) {
        return;
    }
    if (_bmxRtcSession) {
        [_bmxRtcSignalService destroySessionWithSession:_bmxRtcSession];
    }
    _bmxRtcSession = session;
    [_bmxRtcSignalService attachSessionWithSession:session type:BMXRTCSignalService_publishType];
}
- (void)onSessionAttachWithSession:(BMXRTCSession*)session type:(BMXRTCSignalService_HandlerType)type error:(int)error reason:(NSString*)reason{
    if (error) {
        return;
    }
    switch (type) {
        case BMXRTCSignalService_publishType:
            [_bmxRtcSignalService attachSessionWithSession:session type:BMXRTCSignalService_subscribeType];
            break;
            
        case BMXRTCSignalService_subscribeType:
            BMXPubRoomJoinOptions * options = [[BMXPubRoomJoinOptions alloc] initWithUserId:_userId roomId:[_roomId longLongValue]];
            [options setMRoomPin:_pin];
            if ([_roomId isEqualToString:@"0"]) {
                [self createRoomWithPin:_pin session:session];
            }else{
                [_bmxRtcSignalService pubJoinRoomWithSession:session options:options];
            }
            break;
    }
}
- (void)onRoomCreateWithSession:(BMXRTCSession*)session room:(BMXRTCRoom*)room error:(int)error reason:(NSString*)reason{
    if (error) {
        return;
    }
    NSString *strRoomId = [NSString stringWithFormat:@"%lld", [room roomId]];
    _roomId = strRoomId;
    [self pubJoinRoomWithSession:session];
}
- (void)onRoomDestroyWithSession:(BMXRTCSession*)session roomId:(long long)roomId error:(int)error reason:(NSString*)reason{
}
- (void)onRoomEditWithSession:(BMXRTCSession*)session room:(BMXRTCRoom*)room error:(int)error reason:(NSString*)reason{
}
- (void)onRoomExistWithSession:(BMXRTCSession*)session roomId:(long long)roomId exist:(BOOL)exist error:(int)error reason:(NSString*)reason{
}
- (void)onRoomAllowedWithSession:(BMXRTCSession*)session room:(BMXRTCRoom*)room tokens:(TagList*)tokens error:(int)error reason:(NSString*)reason{
}
- (void)onRoomKickWithSession:(BMXRTCSession*)session room:(BMXRTCRoom*)room userId:(long long)userId error:(int)error reason:(NSString*)reason{
}
- (void)onRoomModerateWithSession:(BMXRTCSession*)session room:(BMXRTCRoom*)room userId:(long long)userId error:(int)error reason:(NSString*)reason{
}
- (void)onRoomListWithSession:(BMXRTCSession*)session rooms:(BMXRTCRooms*)rooms error:(int)error reason:(NSString*)reason{
}
- (void)onRoomListParticipantsWithSession:(BMXRTCSession*)session room:(BMXRTCRoom*)room participants:(BMXRTCRoomParticipants*)participants error:(int)error reason:(NSString*)reason{
}

- (void)createRoomWithPin:(NSString *)pin session:(BMXRTCSession*) session {
    BMXRoomCreateOptions *options = [[BMXRoomCreateOptions alloc] initWithRoomId:0 description:@"" secret:@"" pin:pin isPermanent:NO];
    [options setMIsPermanent:NO];
    [_bmxRtcSignalService createRoomWithSession:session options:options];
}

- (void)pubJoinRoomWithSession:(BMXRTCSession*) session {
    BMXPubRoomJoinOptions * options = [[BMXPubRoomJoinOptions alloc] initWithUserId:_userId roomId:[_roomId longLongValue]];
    [options setMRoomPin:_pin];
    [_bmxRtcSignalService pubJoinRoomWithSession:session options:options];
}

- (void)subJoinRoomWithSession:(BMXRTCSession*) session{
    BMXRoomSubJoinOptions *options = [[BMXRoomSubJoinOptions alloc] init];
    [options setMRoomId:[_roomId longLongValue]];
    [options setStreams:_streams];
    [options setMRoomPin:_pin];
    [_bmxRtcSignalService subJoinRoomWithSession:session options:options];
}

- (void)onPubJoinRoomWithSession:(BMXRTCSession*)session room:(BMXRTCRoom*)room publishers:(BMXRTCPublishers*)publishers error:(int)error reason:(NSString*)reason{
    if (error == 426) {
        [self createRoomWithPin:@"" session:session];
        return;
    }else if (error){
        return;
    }
    _roomId = [NSString stringWithFormat:@"%lld", [room roomId]];
    [rtcEngineListener onJoinRoomWithInfo:reason roomId:[_roomId longLongValue] error:(BMXErrorCode)error];
    if (error == BMXErrorCode_NoError) {
        for (int i=0; i<publishers.size; i++) {
            BMXJanusPublisher *publisher = [publishers get:i];
            long long userId = [publisher getMUserId];
            _otherId = userId;
            [rtcEngineListener onMemberJoinedWithRoomId:[_roomId longLongValue] usedId:userId];
            _streams = [publisher getStreams];
            [self subJoinRoomWithSession:session];
        }
    }

}
- (void)onOtherPubJoinRoomWithSession:(BMXRTCSession*)session room:(BMXRTCRoom*)room publishers:(BMXRTCPublishers*)publishers{
    for (int i=0; i<publishers.size; i++) {
        BMXJanusPublisher *publisher = [publishers get:i];
        
        long long userId = [publisher getMUserId];
        _otherId = userId;
        [rtcEngineListener onMemberJoinedWithRoomId:[room roomId] usedId:userId];
        
        BMXRoomSubJoinOptions *options = [[BMXRoomSubJoinOptions alloc] init];
        [options setMRoomId:[room roomId]];
        [options setMUserId:0];
        [options setMPrivateId:userId];
        BMXRTCStreams *streams = [publisher getStreams];
        BMXRTCStreams *realStreams = [[BMXRTCStreams alloc] init];
        for (int j=0; j<streams.size; j++) {
            BMXJanusStreamInfo *streamInfo = [streams get:j];
            NSString *type = [streamInfo getMType];
            BOOL isActive = [streamInfo getMActive];
            if (!isActive){
                continue;
            }
            if ([type isEqualToString: @"video"]) {
                [options setMEnableVideo:YES];
            } else if ([type isEqualToString: @"audio"]) {
                [options setMEnableAudio:YES];
            } else if ([type isEqualToString: @"data"]) {
                [options setMEnableData:YES];
            }
            [realStreams addWithX:streamInfo];
        }
        [options setMAutoClosePc:YES];
        [options setStreams:realStreams];
        [options setMRoomPin:_pin];
        
        [_bmxRtcSignalService subJoinRoomWithSession:session options:options];
    }
}
- (void)onPubConfigureWithSession:(BMXRTCSession*)session room:(BMXRTCRoom*)room sdp:(BMXRoomSDPInfo*)sdp streams:(BMXRTCStreams*)streams error:(int)error reason:(NSString*)reason{
    if (error) {
        return;
    }
    RTCSessionDescription *des = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeAnswer sdp:[sdp getSdp]];
    [_webRtcClient receiveAnswer:des];
    BOOL hasVideo = NO;
    BOOL hasAudio = NO;
    BOOL hasData = NO;
    for (int i=0; i<streams.size; i++) {
        BMXJanusStreamInfo *streamInfo = [streams get:i];
        NSString *type = [streamInfo getMType];
        BOOL isActive = [streamInfo getMActive];
        if (!isActive){
            continue;
        }
        if ([type isEqualToString: @"video"]) {
            hasVideo = YES;
        } else if ([type isEqualToString: @"audio"]) {
            hasAudio = YES;
        } else if ([type isEqualToString: @"data"]) {
            hasData = YES;
        }
    }
    BMXStream *stream = [[BMXStream alloc] init];
    [stream setMUserId: _userId];
    NSString *strRoomId = [NSString stringWithFormat:@"%lld", [room roomId]];
    [stream setMStreamId:strRoomId];
    [stream setMEnableVideo:hasVideo];
    [stream setMEnableAudio:hasAudio];
    [stream setMEnableData:hasData];
    [rtcEngineListener onLocalPublishWithStream:stream info:reason error:(BMXErrorCode)error];
}
- (void)onPubUnPublishWithSession:(BMXRTCSession*)session room:(BMXRTCRoom*)room senderId:(int)senderId error:(int)error reason:(NSString*)reason{
}
- (void)onPublishWebrtcUpWithSession:(BMXRTCSession*)session{
}
- (void)onSubJoinRoomUpdateWithSession:(BMXRTCSession*)session room:(BMXRTCRoom*)room sdp:(BMXRoomSDPInfo*)sdp senderId:(long long)senderId streams:(BMXRTCStreams*)streams error:(int)error reason:(NSString*)reason{
    if (error) {
        return;
    }
    if (!_roomId) {
        return;
    }
    RTCSessionDescription *des = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeOffer sdp:[sdp getSdp]];
    NSString *strRoomId = [NSString stringWithFormat:@"%lld", [room roomId]];
    NSString *strUserId = [NSString stringWithFormat:@"%lld", senderId];
    __weak typeof(self) weakSelf = self;
    [_webRtcClient createAnswerWithRoomId:strRoomId userId:strUserId sdp:des completionHandler:^(RTCSessionDescription * _Nullable sdp1, NSError * _Nullable error) {
        typeof(self) strongSelf = weakSelf;
        if (error) {
            return;
        }
        if (!weakSelf.bmxRtcSession) {
            return;
        }
        BMXRoomSDPInfo* sdpInfo = [[BMXRoomSDPInfo alloc] init];
        [sdpInfo setSdp:[sdp1 sdp]];
        [sdpInfo setType:BMXRoomSDPType_Answer];
        [weakSelf.bmxRtcSignalService subStartWithSession:weakSelf.bmxRtcSession room:room sdp:sdpInfo];
        
        BOOL hasVideo = NO;
        BOOL hasAudio = NO;
        BOOL hasData = NO;
        for (int i=0; i<streams.size; i++) {
            BMXJanusStreamInfo *streamInfo = [streams get:i];
            BOOL isActive = [streamInfo getMActive];
            if (!isActive){
                continue;
            }

            NSString *type = [streamInfo getMType];
            if ([type isEqualToString: @"video"]) {
                hasVideo = YES;
            } else if ([type isEqualToString: @"audio"]) {
                hasAudio = YES;
            } else if ([type isEqualToString: @"data"]) {
                hasData = YES;
            }
        }
        BMXStream *stream = [[BMXStream alloc] init];
        [stream setMUserId: senderId];
        [stream setMStreamId:strRoomId];
        [stream setMEnableVideo:hasVideo];
        [stream setMEnableAudio:hasAudio];
        [stream setMEnableData:hasData];
        [strongSelf->rtcEngineListener onSubscribeWithStream:stream info:reason error:(BMXErrorCode)BMXErrorCode_NoError];
    }];
}
- (void)onSubStartWithSession:(BMXRTCSession*)session room:(BMXRTCRoom*)room error:(int)error reason:(NSString*)reason{
}
- (void)onSubPauseWithSession:(BMXRTCSession*)session room:(BMXRTCRoom*)room error:(int)error reason:(NSString*)reason{
}
- (void)onSubUnsubscribeWithSession:(BMXRTCSession*)session room:(BMXRTCRoom*)room streams:(BMXRTCStreams*)streams error:(int)error reason:(NSString*)reason{
}
- (void)onSubConfigureWithSession:(BMXRTCSession*)session room:(BMXRTCRoom*)room error:(int)error reason:(NSString*)reason{
}
- (void)onSubSwitchWithSession:(BMXRTCSession*)session room:(BMXRTCRoom*)room publisher:(long long)publisher error:(int)error reason:(NSString*)reason{
}
- (void)onLeaveRoomWithSession:(BMXRTCSession*)session roomId:(long long)roomId senderId:(long long)senderId error:(int)error reason:(NSString*)reason{
}
- (void)onSubscribeWebrtcUpWithSession:(BMXRTCSession*)session senderId:(long long)senderId{
}
- (void)onMediaInfoWithSession:(BMXRTCSession*)session senderId:(long long)senderId type:(BMXTrackType)type receiving:(BOOL)receiving mid:(NSString*)mid{
}
- (void)onSlowlinkWithSession:(BMXRTCSession*)session senderId:(long long)senderId uplink:(BOOL)uplink nacks:(int)nacks{
}
- (void)onHangupWithSession:(BMXRTCSession*)session senderId:(long long)senderId reason:(NSString*)reason{
}
- (void)onSessionHangupWithSession:(BMXRTCSession*)session error:(long long)error reason:(NSString*)reason{
}
- (void)onSessionDetachWithSession:(BMXRTCSession*)session type:(BMXRTCSignalService_HandlerType)type error:(int)error reason:(NSString*)reason{
}
- (void)onSessionDestroyWithSessionId:(long long)sessionId error:(int)error reason:(NSString*)reason{
    NSLog(@"onSessionDestroyWithSessionId:%lld e:%d r:%@", sessionId, error, reason);
    if (error == 0 && sessionId == _bmxRtcSession.sessionId) {
        _bmxRtcSession = nil;
    }
}

@end
