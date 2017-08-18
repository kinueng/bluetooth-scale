#import "HealthKitManager.h"
#import <HealthKit/HealthKit.h>


@interface HealthKitManager ()

@property (nonatomic, retain) HKHealthStore *healthStore;

@end


@implementation HealthKitManager

+ (HealthKitManager *)sharedManager {
    static dispatch_once_t pred = 0;
    static HealthKitManager *instance = nil;
    dispatch_once(&pred, ^{
        instance = [[HealthKitManager alloc] init];
        instance.healthStore = [[HKHealthStore alloc] init];
    });
    return instance;
}

- (void)requestAuthorization {
    
    if ([HKHealthStore isHealthDataAvailable] == NO) {
        // If our device doesn't support HealthKit -> return.
        return;
    }
    
    NSArray *readTypes = @[[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDietaryWater],
                           [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDietaryCaffeine]];
    
    NSArray *writeTypes = @[[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDietaryWater],
                            [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDietaryCaffeine]];
    
    [self.healthStore requestAuthorizationToShareTypes:[NSSet setWithArray:writeTypes]
                                             readTypes:[NSSet setWithArray:readTypes] completion:nil];
}

- (NSDate *)readBirthDate {
    NSError *error;
    NSDate *dateOfBirth = [self.healthStore dateOfBirthWithError:&error];   // Convenience method of HKHealthStore to get date of birth directly.
    
    if (!dateOfBirth) {
        NSLog(@"Either an error occured fetching the user's age information or none has been stored yet. In your app, try to handle this gracefully.");
    }
    
    return dateOfBirth;
}

- (void)writeWaterSample:(CGFloat)weight {
    
    // Each quantity consists of a value and a unit.
    HKUnit *milliLitersUnits = [HKUnit literUnitWithMetricPrefix:HKMetricPrefixMilli];
    HKQuantity *volumeQuantity = [HKQuantity quantityWithUnit:milliLitersUnits doubleValue:weight];
    
    HKQuantityType *weightType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierDietaryWater];
    NSDate *now = [NSDate date];
    
    // For every sample, we need a sample type, quantity and a date.
    HKQuantitySample *weightSample = [HKQuantitySample quantitySampleWithType:weightType quantity:volumeQuantity startDate:now endDate:now];
    
    [self.healthStore saveObject:weightSample withCompletion:^(BOOL success, NSError *error) {
        if (!success) {
            NSLog(@"Error while saving weight (%f) to Health Store: %@.", weight, error);
        }
    }];
}

- (void)writeWeightSample:(CGFloat)weight {
    
    // Each quantity consists of a value and a unit.
    HKUnit *kilogramUnit = [HKUnit gramUnitWithMetricPrefix:HKMetricPrefixKilo];
    HKQuantity *weightQuantity = [HKQuantity quantityWithUnit:kilogramUnit doubleValue:weight];
    
    HKQuantityType *weightType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMass];
    NSDate *now = [NSDate date];
    
    // For every sample, we need a sample type, quantity and a date.
    HKQuantitySample *weightSample = [HKQuantitySample quantitySampleWithType:weightType quantity:weightQuantity startDate:now endDate:now];
    
    [self.healthStore saveObject:weightSample withCompletion:^(BOOL success, NSError *error) {
        if (!success) {
            NSLog(@"Error while saving weight (%f) to Health Store: %@.", weight, error);
        }
    }];
}

- (void)writeWorkoutDataFromModelObject:(id)workoutModelObject {
    
    // In a real world app, you would pass in a model object representing your workout data, and you would pull the relevant data here and pass it to the HealthKit workout method.
    
    // For the sake of simplicity of this example, we will just set arbitrary data.
    NSDate *startDate = [NSDate date];
    NSDate *endDate = [startDate dateByAddingTimeInterval:60 * 60 * 2];
    NSTimeInterval duration = [endDate timeIntervalSinceDate:startDate];
    CGFloat distanceInMeters = 57000.;
    
    HKQuantity *distanceQuantity = [HKQuantity quantityWithUnit:[HKUnit meterUnit] doubleValue:(double)distanceInMeters];
    
    HKWorkout *workout = [HKWorkout workoutWithActivityType:HKWorkoutActivityTypeRunning
                                                  startDate:startDate
                                                    endDate:endDate
                                                   duration:duration
                                          totalEnergyBurned:nil
                                              totalDistance:distanceQuantity
                                                   metadata:nil];
    
    [self.healthStore saveObject:workout withCompletion:^(BOOL success, NSError *error) {
        NSLog(@"Saving workout to healthStore - success: %@", success ? @"YES" : @"NO");
        if (error != nil) {
            NSLog(@"error: %@", error);
        }
    }];
}

@end
