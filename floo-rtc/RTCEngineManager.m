#import "RTCEngineManager.h"
#import "MaxEngineFactory.h"

@implementation RTCEngineManager

+ (BMXRTCEngine *)engineWithType:(ERtcEngineType) type {

    BaseEngineFactory *factory;
    if (type == kMaxEngine) {
        factory = [[MaxEngineFactory alloc] init];
//    } else if (type == kUCloudEngine) {
//        factory = [[UCloudEngineFactory alloc] init];
    }
    if (factory) {
        return [factory engine];
    }else{
        return nil;
    }
}

@end
