#import "WebRtcClient.h"
#import <WebRtc/RTCDefaultVideoDecoderFactory.h>
#import <WebRtc/RTCDefaultVideoEncoderFactory.h>
#import <WebRtc/RTCPeerConnectionFactory.h>
#import <WebRtc/RTCIceServer.h>
#import <WebRtc/RTCMediaConstraints.h>
#import <WebRtc/RTCSessionDescription.h>
#import <LocalTrack.h>
#import <Peer.h>

@interface WebRtcClient ()
@property(nonatomic, assign) BOOL hasVideo;

@end

@implementation WebRtcClient

@synthesize factory = _factory;
@synthesize config = _config;

static NSString * const kARDMediaStreamId = @"ARDAMS";
static NSString * const kARDAudioTrackId = @"ARDAMSa0";

- (NSArray<RTCVideoCodecInfo *> *)availableVideoCodecs {
  return [RTCDefaultVideoEncoderFactory supportedCodecs];
}

- (instancetype)init {
    if (self = [super init]) {
        RTCDefaultVideoDecoderFactory *decoderFactory = [[RTCDefaultVideoDecoderFactory alloc] init];
        RTCDefaultVideoEncoderFactory *encoderFactory = [[RTCDefaultVideoEncoderFactory alloc] init];
        encoderFactory.preferredCodec = [self availableVideoCodecs][0];
        _factory = [[RTCPeerConnectionFactory alloc] initWithEncoderFactory:encoderFactory
                                                             decoderFactory:decoderFactory];
        
        _config = [[RTCConfiguration alloc] init];
        RTCCertificate *pcert = [RTCCertificate generateCertificateWithParams:@{
          @"expires" : @10000000000,
          @"name" : @"RSASSA-PKCS1-v1_5"
        }];
        NSMutableArray *arr = [[NSMutableArray alloc] init];
        RTCIceServer * iceServer = [[RTCIceServer alloc] initWithURLStrings:@[@"stun:stun.xten.com"]];
        [arr addObject:iceServer];
        _config.iceServers = arr;
        _config.sdpSemantics = RTCSdpSemanticsUnifiedPlan;
        _config.certificate = pcert;
        
        NSDictionary *optionalConstraints = @{ @"DtlsSrtpKeyAgreement" : @"true",
                                               @"googEchoCancellation" : @"true",
                                               @"googAutoGainControl" : @"true",
                                               @"googHighpassFilter" : @"true",
                                               @"OfferToReceiveAudio" : @"true",
                                               @"OfferToReceiveVideo" : @"true",
                                               @"googNoiseSuppression" : @"true"
        };
        _mediaConstraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil
                         optionalConstraints:optionalConstraints];
        
        _localTrack = [[LocalTrack alloc] initWithRTCPeerConnectionFactory:_factory];
        if (!_peers) {
            _peers = [[NSMutableDictionary<NSString *, Peer*> alloc] init];
        }

    }
    return self;
}

- (void)startLocalPreview:(RTCCameraPreviewView *)localVideoView{
    _localVideoView = localVideoView;
    [_localTrack startLocalPreview:localVideoView];
}

- (void) stopLocalPreview{
    if (_hasVideo) {
        [self stopCapture];
    }
    [_myPeer removeTracks];
    NSEnumerator * enumeratorValue = [_peers objectEnumerator];
    for (Peer *peer in enumeratorValue) {
        [peer removeTracks];
    }
    _peers = [[NSMutableDictionary<NSString *, Peer*> alloc] init];
}

- (void) stopCapture{
    [_remoteVideoTrack removeRenderer:_remoteVideoView];
    [_remoteVideoTrack setIsEnabled:YES];
    _remoteVideoTrack = nil;
    [_remoteVideoView renderFrame:nil];

    [_localTrack stopCapture];
}

- (void)startRemoteViewWithCanvas:(BMXVideoCanvas *)canvas {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        typeof(self) strongSelf = weakSelf;
        if (!canvas) {
            return;
        }
        
        NSString *userId = [NSString stringWithFormat:@"%lld", [canvas getMUserId]];
        RTCVideoTrack *remoteVideoTrack = [self remoteVideoTrackOfUserId:userId];
        RTCMTLVideoView *remoteVideoView = (RTCMTLVideoView *)[canvas getMView];
        if (!remoteVideoView) {
            return;
        }
        if (strongSelf.remoteVideoTrack == remoteVideoTrack) {
            return;
        }
        remoteVideoView.contentMode = UIViewContentModeScaleAspectFit;
        BMXRenderMode mode = [canvas getMRenderMode];
        if (mode == BMXRenderMode_Default) {
            remoteVideoView.contentMode = UIViewContentModeScaleToFill;
        }else if (mode == BMXRenderMode_Fill){
            remoteVideoView.contentMode = UIViewContentModeScaleAspectFill;
        }

        [strongSelf.remoteVideoTrack removeRenderer:strongSelf.remoteVideoView];
        strongSelf.remoteVideoTrack = nil;
        [strongSelf.remoteVideoView renderFrame:nil];

        strongSelf.remoteVideoTrack = remoteVideoTrack;
        strongSelf.remoteVideoView = remoteVideoView;
        [strongSelf.remoteVideoTrack addRenderer:strongSelf.remoteVideoView];
    });

}

- (void)createOfferWithRoomId:(NSString *)roomId hasVideo:(BOOL) hasVideo hasAudio:(BOOL) hasAudio completionHandler:(nullable void (^)(RTCSessionDescription *_Nullable sdp, NSError *_Nullable error))completionHandler{
    _hasVideo = hasVideo;
    _myPeer = [[Peer alloc] initWithRTCPeerConnectionFactory:_factory rtcConfiguration:_config];
    if (hasVideo) {
        RTCVideoTrack *videoTrack = [_localTrack createLocalVideoTrack];
        if (videoTrack) {
          [_myPeer addTrack:videoTrack streamIds:@[ kARDMediaStreamId ]];
        }

    }
    if (hasAudio) {
        RTCAudioTrack *audioTrack = [_localTrack createLocalAudioTrack];
        if (audioTrack) {
            [_myPeer addTrack:audioTrack streamIds:@[ kARDMediaStreamId ]];
        }
    }
    [_myPeer offerForConstraints:_mediaConstraints completionHandler:completionHandler];
}

- (void)receiveAnswer:(RTCSessionDescription *) sdp{
    [_myPeer receiveAnswer:sdp];
}

- (Peer *)getPeerByUserId:(NSString *)userId{
    Peer *p = _peers[userId];
    if (!p) {
        p = [[Peer alloc] initWithRTCPeerConnectionFactory:_factory rtcConfiguration:_config];
        _peers[userId] = p;
    }
    return p;
}

- (void)createAnswerWithRoomId:(NSString *)roomId userId:(NSString *)userId sdp: (RTCSessionDescription *)sdp completionHandler:(nullable void (^)(RTCSessionDescription *_Nullable sdp, NSError *_Nullable error))completionHandler{
    Peer * p = [self getPeerByUserId:userId];
    if (p) {
        __weak typeof(self) weakSelf = self;
       [p setRemoteDescription:sdp completionHandler:^(NSError * _Nullable error) {
            if (!error) {
                typeof(self) strongSelf = weakSelf;
                Peer * p = [strongSelf getPeerByUserId:userId];
                [p answerForConstraints:strongSelf.mediaConstraints completionHandler:completionHandler];
            }
        }];
    }
}
- (void)switchCamera{
    [_localTrack switchCamera];
}

- (RTCVideoTrack *)remoteVideoTrackOfUserId:(NSString*) userId {
    Peer *p = [self getPeerByUserId:userId];
    return [p videoTrack];
}

- (void)muteLocalAudioWithMute:(BOOL)mute{
    [_localTrack muteLocalAudioWithMute:mute];
}

- (void)muteLocalVideoWithType:(BMXVideoMediaType)type mute:(BOOL)mute{
    [_localTrack muteLocalVideoWithType:type mute:mute];
}

- (void)setVideoWidth:(int)width height:(int)height frameRate:(int)frameRate{
    [_localTrack setVideoWidth:width height:height frameRate:frameRate];
}
@end
