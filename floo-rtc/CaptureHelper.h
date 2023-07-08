#import <WebRTC/RTCCameraVideoCapturer.h>
#import <WebRTC/RTCVideoSource.h>
#import <WebRTC/RTCCameraPreviewView.h>

@class RTCCameraVideoCapturer;

@interface CaptureHelper : NSObject
@property(nonatomic, strong) RTCCameraVideoCapturer *capturer;
@property(nonatomic, strong) RTCCameraPreviewView *localVideoView;

- (instancetype)initWithVideoSource:(RTCVideoSource *)videoSource;
- (void)startCaptureWithView:(RTCCameraPreviewView *)localVideoView;
- (void)stopCapture;
- (void)switchCamera;
- (void)setVideoWidth:(int)width height:(int)height frameRate:(int)frameRate;
@end
