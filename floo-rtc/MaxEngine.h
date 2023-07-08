#import <Foundation/Foundation.h>
#import <WebRTC/RTCVideoTrack.h>
#import <WebRTC/RTCAudioTrack.h>
#import <floo-ios/floo_proxy.h>

@class WebRtcClient;

@interface MaxEngine  : BMXRTCEngine

@property(nonatomic, strong) WebRtcClient *webRtcClient;
@property(nonatomic, strong) BMXRTCSignalService *bmxRtcSignalService;
@property(nonatomic, strong) BMXRTCSession *bmxRtcSession;
@property(nonatomic, strong) BMXRTCStreams *streams;
@property(nonatomic, strong) NSString *roomId;
@property(nonatomic, strong) NSString *pin;
@property(nonatomic, assign) long long userId;

+ (instancetype)sharedEngine;
- (instancetype)init;
@end
