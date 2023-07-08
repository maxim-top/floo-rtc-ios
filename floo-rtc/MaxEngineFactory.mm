#import "MaxEngineFactory.h"
#import "MaxEngine.h"

@implementation MaxEngineFactory

- (BMXRTCEngine *)engine {
    return [MaxEngine sharedEngine];
}

@end
