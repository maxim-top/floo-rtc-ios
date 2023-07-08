#import "LocalTrack.h"
#import <WebRTC/RTCMediaConstraints.h>
#import <WebRTC/RTCPeerConnectionFactory.h>
#import <WebRTC/RTCMediaStream.h>
#import <WebRTC/RTCRtpTransceiver.h>
#import <WebRTC/RTCVideoTrack.h>
#import <WebRTC/RTCAudioTrack.h>
#import <WebRTC/RTCCameraVideoCapturer.h>
#import <WebRTC/RTCVideoSource.h>

static NSString * const kARDVideoTrackId = @"ARDAMSv0";
static NSString * const kARDAudioTrackId = @"ARDAMSa0";

@interface LocalTrack ()
{
}

@property(nonatomic, assign) int width;
@property(nonatomic, assign) int height;
@property(nonatomic, assign) int frameRate;

@end

@implementation LocalTrack

- (instancetype)initWithRTCPeerConnectionFactory:(RTCPeerConnectionFactory *)factory {
    _factory = factory;
    _videoSource = [_factory videoSource];
    _captureHelper = [[CaptureHelper alloc] initWithVideoSource:_videoSource];
    return self;
}

- (RTCMediaConstraints *)defaultMediaAudioConstraints {
  NSDictionary *mandatoryConstraints = @{};
  RTCMediaConstraints *constraints =
      [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints
                                            optionalConstraints:nil];
  return constraints;
}

- (RTCAudioTrack *)createLocalAudioTrack {
    if (!_audioTrack) {
        RTCMediaConstraints *constraints = [self defaultMediaAudioConstraints];
        RTCAudioSource *source = [_factory audioSourceWithConstraints:constraints];
        _audioTrack = [_factory audioTrackWithSource:source
                                                      trackId:kARDAudioTrackId];
    }
    return _audioTrack;
}
- (RTCVideoTrack *)createLocalVideoTrack {
    if (!_videoTrack) {
        _videoTrack = [_factory videoTrackWithSource:_videoSource trackId:kARDVideoTrackId];
    }

    return _videoTrack;
}

- (void)startLocalPreview:(RTCCameraPreviewView *)localVideoView{
    [_captureHelper setVideoWidth:_width height:_height frameRate:_frameRate];
    [_captureHelper startCaptureWithView:localVideoView];
    [_videoTrack setIsEnabled:YES];
}

- (void)stopCapture{
    [_captureHelper stopCapture];
    [_videoTrack setIsEnabled:NO];
}

- (void)switchCamera{
    [_captureHelper switchCamera];
}

- (void)muteLocalAudioWithMute:(BOOL)mute{
    [_audioTrack setIsEnabled:!mute];
}

- (void)muteLocalVideoWithType:(BMXVideoMediaType)type mute:(BOOL)mute{
    [_videoTrack setIsEnabled:!mute];
}

- (void)setVideoWidth:(int)width height:(int)height frameRate:(int)frameRate{
    _width = width;
    _height = height;
    _frameRate = frameRate;
}
@end
