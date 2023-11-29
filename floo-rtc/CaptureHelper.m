#import "CaptureHelper.h"
#import <WebRTC/RTCLogging.h>

const Float64 kFramerateLimit = 30.0;
@interface CaptureHelper ()

@property(nonatomic, assign) int width;
@property(nonatomic, assign) int height;
@property(nonatomic, assign) int frameRate;

@end

@implementation CaptureHelper {
  BOOL _isFrontCamera;
}

- (instancetype)initWithVideoSource:(RTCVideoSource *)videoSource{
  if (self = [super init]) {
  #if !TARGET_IPHONE_SIMULATOR
      RTCCameraVideoCapturer *capturer = [[RTCCameraVideoCapturer alloc] initWithDelegate:videoSource];
      _capturer = capturer;
  #endif
    _isFrontCamera = YES;
  }

  return self;
}

- (void)startCaptureWithView:(RTCCameraPreviewView *)localVideoView {
  _localVideoView = localVideoView;
  _localVideoView.captureSession = _capturer.captureSession;
  AVCaptureDevicePosition pos =
      _isFrontCamera ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
  AVCaptureDevice *device = [self findDeviceForPosition:pos];
  AVCaptureDeviceFormat *format = [self selectFormatForDevice:device];
  if (format == nil) {
    NSLog(@"No valid formats for device %@", device);
    return;
  }

  NSInteger fps = [self selectFpsForFormat:format];
  [_capturer startCaptureWithDevice:device format:format fps:fps];
}

- (void)stopCapture {
    if (_localVideoView) {
        _localVideoView.captureSession = nil;
        _localVideoView = nil;
    }
    [_capturer stopCapture];
}

- (void)switchCamera {
  _isFrontCamera = !_isFrontCamera;
  [self startCaptureWithView:_localVideoView];
}


- (AVCaptureDevice *)findDeviceForPosition:(AVCaptureDevicePosition)position {
  NSArray<AVCaptureDevice *> *captureDevices = [RTCCameraVideoCapturer captureDevices];
  for (AVCaptureDevice *device in captureDevices) {
    if (device.position == position) {
      return device;
    }
  }
  if(captureDevices.count > 0){
    return captureDevices[0];
  }else{
    return nil;
  }
}

- (AVCaptureDeviceFormat *)selectFormatForDevice:(AVCaptureDevice *)device {
  NSArray<AVCaptureDeviceFormat *> *formats =
      [RTCCameraVideoCapturer supportedFormatsForDevice:device];
  int targetWidth = _width;
  int targetHeight = _height;
  AVCaptureDeviceFormat *selectedFormat = nil;
  int currentDiff = INT_MAX;

  for (AVCaptureDeviceFormat *format in formats) {
    CMVideoDimensions dimension = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
    FourCharCode pixelFormat = CMFormatDescriptionGetMediaSubType(format.formatDescription);
    int diff = abs(targetWidth - dimension.width) + abs(targetHeight - dimension.height);
    if (diff < currentDiff) {
      selectedFormat = format;
      currentDiff = diff;
    } else if (diff == currentDiff && pixelFormat == [_capturer preferredOutputPixelFormat]) {
      selectedFormat = format;
    }
  }

  return selectedFormat;
}

- (NSInteger)selectFpsForFormat:(AVCaptureDeviceFormat *)format {
  Float64 maxSupportedFramerate = 0;
  for (AVFrameRateRange *fpsRange in format.videoSupportedFrameRateRanges) {
    maxSupportedFramerate = fmax(maxSupportedFramerate, fpsRange.maxFrameRate);
  }
  return fmin(maxSupportedFramerate, kFramerateLimit);
}

- (void)setVideoWidth:(int)width height:(int)height frameRate:(int)frameRate{
    _width = width;
    _height = height;
    _frameRate = frameRate;
}
@end
