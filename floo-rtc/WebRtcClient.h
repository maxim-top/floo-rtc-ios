#import <Foundation/Foundation.h>
#import <WebRTC/RTCConfiguration.h>
#import <WebRTC/RTCCameraPreviewView.h>
#import <WebRTC/RTCMTLVideoView.h>
#import <WebRTC/RTCVideoTrack.h>
#import <WebRTC/RTCAudioTrack.h>
#import <WebRTC/RTCAudioTrack.h>
#import <floo-ios/floo_proxy.h>
#import <LocalTrack.h>
#import <Peer.h>

@class RTCPeerConnectionFactory;

@interface WebRtcClient  : NSObject 

@property(nonatomic, strong) RTCPeerConnectionFactory *factory;
@property(nonatomic, strong) RTCConfiguration *config;
@property(nonatomic, strong) RTCMediaConstraints *mediaConstraints;
@property(nonatomic, strong) NSMutableDictionary<NSString *, Peer*> *peers;
@property(nonatomic, strong) Peer *myPeer;
@property(nonatomic, strong) LocalTrack *localTrack;
@property(nonatomic, strong) RTCCameraPreviewView *localVideoView;
@property(nonatomic, strong) RTCMTLVideoView *remoteVideoView;
@property(nonatomic, strong) RTCVideoTrack *remoteVideoTrack;

- (instancetype)init;
- (void)startLocalPreview:(RTCCameraPreviewView *)localVideoView;
- (void)stopLocalPreview;
- (void)stopCapture;
- (void)startRemoteViewWithCanvas:(BMXVideoCanvas *)canvas;
- (void)createOfferWithRoomId:(NSString *)roomId hasVideo:(BOOL) hasVideo hasAudio:(BOOL) hasAudio completionHandler:(nullable void (^)(RTCSessionDescription *_Nullable sdp, NSError *_Nullable error))completionHandler;
- (void)receiveAnswer:(RTCSessionDescription *) sdp;
- (void)createAnswerWithRoomId:(NSString *)roomId userId:(NSString *)userId sdp: (RTCSessionDescription *)sdp completionHandler:(nullable void (^)(RTCSessionDescription *_Nullable sdp, NSError *_Nullable error))completionHandler;
- (void)switchCamera;
- (RTCVideoTrack *)remoteVideoTrackOfUserId:(NSString*) userId;
- (void)muteLocalAudioWithMute:(BOOL)mute;
- (void)muteLocalVideoWithType:(BMXVideoMediaType)type mute:(BOOL)mute;
- (void)setVideoWidth:(int)width height:(int)height frameRate:(int)frameRate;
@end
