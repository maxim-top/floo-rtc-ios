
#import <Foundation/Foundation.h>
#import <WebRTC/RTCPeerConnection.h>
#import <WebRTC/RTCConfiguration.h>
#import <WebRTC/RTCMediaStreamTrack.h>

@class RTCPeerConnectionFactory;
@class RTCVideoTrack;
@class RTCAudioTrack;

@interface Peer : NSObject<RTCPeerConnectionDelegate>

@property(nonatomic, strong) RTCPeerConnection *_Nullable peerConnection;
@property(nonatomic, strong) RTCVideoTrack *_Nullable videoTrack;
@property(nonatomic, strong) RTCAudioTrack *_Nullable audioTrack;
@property (assign, nonatomic) BOOL isCreateOffer;
@property(nonatomic, strong) RTCConfiguration *_Nullable config;

- (instancetype _Nullable)initWithRTCPeerConnectionFactory:(RTCPeerConnectionFactory *_Nullable)factory
                        rtcConfiguration:(RTCConfiguration *_Nullable)config;

- (void)offerForConstraints:(RTCMediaConstraints *_Nullable)constraints
          completionHandler:(nullable void (^)(RTCSessionDescription *_Nullable sdp,
                                               NSError *_Nullable error))completionHandler;
- (void)answerForConstraints:(RTCMediaConstraints *_Nullable)constraints
           completionHandler:(nullable void (^)(RTCSessionDescription *_Nullable sdp,
                                                NSError *_Nullable error))completionHandler;

- (void)setLocalDescription:(RTCSessionDescription *_Nullable)sdp
          completionHandler:(nullable void (^)(NSError *_Nullable error))completionHandler;

- (void)setRemoteDescription:(RTCSessionDescription *_Nullable)sdp
           completionHandler:(nullable void (^)(NSError *_Nullable error))completionHandler;

- (void)addTrack:(RTCMediaStreamTrack *_Nullable)track streamIds:(NSArray<NSString *> *_Nullable)streamIds;

- (void)removeTracks;

- (void)receiveAnswer:(RTCSessionDescription *_Nullable) sdp;
@end
