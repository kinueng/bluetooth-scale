#import <UIKit/UIKit.h>

@interface HealthKitManager : NSObject

+ (HealthKitManager *)sharedManager;
- (void)requestAuthorization;
- (void)writeWaterSample:(CGFloat)weight;
- (void)writeWeightSample:(CGFloat)weight;

@end
