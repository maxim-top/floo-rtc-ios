
#import <Foundation/Foundation.h>
#import <WebRTC/RTCPeerConnection.h>
#import <WebRTC/RTCConfiguration.h>
#import <WebRTC/RTCCameraPreviewView.h>
#import <CaptureHelper.h>
#import <floo-ios/floo_proxy.h>

@class RTCPeerConnectionFactory;
@class RTCVideoTrack;
@class RTCAudioTrack;
@class RTCVideoSource;

@interface LocalTrack : NSObject

@property(nonatomic, strong) RTCPeerConnectionFactory *factory;
@property(nonatomic, strong) RTCConfiguration *config;
@property(nonatomic, strong) RTCMediaConstraints *defaultPeerConnectionConstraints;
@property(nonatomic, strong) RTCVideoTrack *videoTrack;
@property(nonatomic, strong) RTCAudioTrack *audioTrack;
@property(nonatomic, strong) RTCVideoSource *videoSource;
@property(nonatomic, strong) CaptureHelper *captureHelper;

- (instancetype)initWithRTCPeerConnectionFactory:(RTCPeerConnectionFactory *)factory;
- (RTCVideoTrack *)createLocalVideoTrack;
- (RTCAudioTrack *)createLocalAudioTrack;
- (void)stopCapture;
- (void)switchCamera;
- (void)startLocalPreview:(RTCCameraPreviewView *)localVideoView;
- (void)muteLocalAudioWithMute:(BOOL)mute;
- (void)muteLocalVideoWithType:(BMXVideoMediaType)type mute:(BOOL)mute;
- (void)setVideoWidth:(int)width height:(int)height frameRate:(int)frameRate;
@end
