#import "Peer.h"
#import <WebRTC/RTCMediaConstraints.h>
#import <WebRTC/RTCPeerConnectionFactory.h>
#import <WebRTC/RTCMediaStream.h>
#import <WebRTC/RTCRtpTransceiver.h>
#import <WebRTC/RTCVideoTrack.h>
#import <WebRTC/RTCAudioTrack.h>
#import <WebRtc/RTCIceServer.h>

@interface Peer ()
{
}
@property(nonatomic, strong) NSMutableArray<RTCRtpSender * > *tracks;

@end

@implementation Peer
@synthesize config = _config;

- (instancetype)init {
    if (self = [super init]) {
        _tracks = [NSMutableArray array];
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
    }
    return self;
}

- (RTCMediaConstraints *)defaultPeerConnectionConstraints {
  NSString *value = @"true";
  NSDictionary *optionalConstraints = @{ @"DtlsSrtpKeyAgreement" : value };
  RTCMediaConstraints* constraints =
      [[RTCMediaConstraints alloc]
          initWithMandatoryConstraints:nil
                   optionalConstraints:optionalConstraints];
  return constraints;
}

- (instancetype)initWithRTCPeerConnectionFactory:(RTCPeerConnectionFactory *)factory
                                rtcConfiguration:(RTCConfiguration *)config{
    if (self = [super init]) {
        _tracks = [NSMutableArray array];
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
    }
    RTCMediaConstraints *constraints = [self defaultPeerConnectionConstraints];
    _peerConnection = [factory peerConnectionWithConfiguration:_config
                                                    constraints:constraints
                                                       delegate:self];
    return self;
}

- (void)answerForConstraints:(RTCMediaConstraints *)constraints
           completionHandler:(nullable void (^)(RTCSessionDescription *_Nullable sdp,
                                                NSError *_Nullable error))completionHandler{
    __weak typeof(self) weakSelf = self;
    [_peerConnection answerForConstraints:constraints completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
        typeof(self) strongSelf = weakSelf;
        [strongSelf.peerConnection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
        }];
        completionHandler(sdp, error);
    }];
}

- (void)setLocalDescription:(RTCSessionDescription *)sdp
          completionHandler:(nullable void (^)(NSError *_Nullable error))completionHandler{
    [_peerConnection setLocalDescription:sdp completionHandler:completionHandler];
}

- (void)setRemoteDescription:(RTCSessionDescription *)sdp
           completionHandler:(nullable void (^)(NSError *_Nullable error))completionHandler{
    [_peerConnection setRemoteDescription:sdp completionHandler:completionHandler];
}

- (void)offerForConstraints:(RTCMediaConstraints *)constraints
          completionHandler:(nullable void (^)(RTCSessionDescription *_Nullable sdp,
                                               NSError *_Nullable error))completionHandler{
    __weak typeof(self) weakSelf = self;
    [_peerConnection offerForConstraints:constraints completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
        typeof(self) strongSelf = weakSelf;
        [strongSelf.peerConnection setLocalDescription:sdp
                               completionHandler:^(NSError *error) {}];
        completionHandler(sdp, error);
        
    }];
    
    for (RTCRtpTransceiver *transceiver in _peerConnection.transceivers) {
      if (transceiver.mediaType == RTCRtpMediaTypeVideo) {
          _videoTrack = (RTCVideoTrack *)transceiver.receiver.track;
      } else if (transceiver.mediaType == RTCRtpMediaTypeAudio) {
          _audioTrack = (RTCAudioTrack *)transceiver.receiver.track;
      }
    }
}

- (void)removeTracks{
    for (RTCRtpSender *track in _tracks) {
        [_peerConnection removeTrack:track];
    }
    [_peerConnection close];
}
- (void)addTrack:(RTCMediaStreamTrack *)track streamIds:(NSArray<NSString *> *)streamIds{
    [_tracks addObject: [_peerConnection addTrack:track streamIds:streamIds]];
}

- (void)receiveAnswer:(RTCSessionDescription *) sdp{
    [_peerConnection setRemoteDescription:sdp completionHandler:^(NSError * _Nullable error) {}];
}

#pragma mark - RTCPeerConnectionDelegate
// Callbacks for this delegate occur on non-main thread and need to be
// dispatched back to main queue as needed.

- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didChangeSignalingState:(RTCSignalingState)stateChanged {
  NSLog(@"PEERCONN:Signaling state changed: %ld %@", (long)stateChanged, peerConnection);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
          didAddStream:(RTCMediaStream *)stream {
  NSLog(@"PEERCONN:Stream with %lu video tracks and %lu audio tracks was added. %@",
         (unsigned long)stream.videoTracks.count,
         (unsigned long)stream.audioTracks.count,peerConnection);
    if (stream.videoTracks.count > 0) {
        _videoTrack = stream.videoTracks[0];
    }
    _audioTrack = stream.audioTracks[0];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didStartReceivingOnTransceiver:(RTCRtpTransceiver *)transceiver {
  RTCMediaStreamTrack *track = transceiver.receiver.track;
  NSLog(@"PEERCONN:Now receiving %@ on track %@ %@.", track.kind, track.trackId, peerConnection);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
       didRemoveStream:(RTCMediaStream *)stream {
  NSLog(@"PEERCONN:Stream was removed.");
}

- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection {
  NSLog(@"PEERCONN:WARNING: Renegotiation needed but unimplemented.");
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didChangeIceConnectionState:(RTCIceConnectionState)newState {
  NSLog(@"PEERCONN:ICE state changed: %ld %@", (long)newState, peerConnection);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didChangeConnectionState:(RTCPeerConnectionState)newState {
  NSLog(@"PEERCONN:ICE+DTLS state changed: %ld conn:%@", (long)newState, peerConnection);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didChangeIceGatheringState:(RTCIceGatheringState)newState {
  NSLog(@"PEERCONN:ICE gathering state changed: %ld %@", (long)newState, peerConnection);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didGenerateIceCandidate:(RTCIceCandidate *)candidate {
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didRemoveIceCandidates:(NSArray<RTCIceCandidate *> *)candidates {
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
     didChangeLocalCandidate:(RTCIceCandidate *)local
    didChangeRemoteCandidate:(RTCIceCandidate *)remote
              lastReceivedMs:(int)lastDataReceivedMs
               didHaveReason:(NSString *)reason {
  NSLog(@"PEERCONN:ICE candidate pair changed because: %@", reason);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didOpenDataChannel:(RTCDataChannel *)dataChannel {
}

#pragma mark - RTCSessionDescriptionDelegate
// Callbacks for this delegate occur on non-main thread and need to be
// dispatched back to main queue as needed.

- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didCreateSessionDescription:(RTCSessionDescription *)sdp
                          error:(NSError *)error {
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didSetSessionDescriptionWithError:(NSError *)error {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
    typeof(self) strongSelf = weakSelf;
    if (error) {
      return;
    }
    // If we're answering and we've just set the remote offer we need to create
    // an answer and set the local description.
    if (!self.peerConnection.localDescription) {
        NSDictionary *optionalConstraints = @{ @"DtlsSrtpKeyAgreement" : @"true",
                                               @"googEchoCancellation" : @"true",
                                               @"googAutoGainControl" : @"true",
                                               @"googHighpassFilter" : @"true",
                                               @"OfferToReceiveAudio" : @"true",
                                               @"OfferToReceiveVideo" : @"true",
                                               @"googNoiseSuppression" : @"true"
        };
      RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil
                                                                               optionalConstraints:optionalConstraints];
      [strongSelf.peerConnection answerForConstraints:constraints
                              completionHandler:^(RTCSessionDescription *sdp, NSError *error) {
                                
                              }];
    }
  });
}

@end
