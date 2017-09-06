#import "BLEScaleReader.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "HealthKitManager.h"

#define RESCAN_WAIT_TIME 3.0
#define BLE_SCAN_INTERVAL  2.0

//#define TARGET_BLE_UUID @"4AAA7263-F13F-482F-9F8C-6EE1637BD534"
#define TARGET_BLE_UUID @"4EE1B9FB-ED46-4C9C-96C6-5112A8EA3E3F"
#define TARGET_BLE_SERVICE_UUID @"FFF0"
#define TARGET_BLE_CHARACTERISIC_UUID @"FFF4"

@interface BLEScaleReader () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *backgroundImageView;

@property (weak, nonatomic) IBOutlet UIView *controlContainerView;
@property (weak, nonatomic) IBOutlet UIView *circleView;
@property (weak, nonatomic) IBOutlet UILabel *weightLabel;
@property (weak, nonatomic) IBOutlet UISwitch *recordCupWeightSwitch;
@property (weak, nonatomic) IBOutlet UITextField *currentCupWeight;

- (IBAction)saveCupWeightButton:(id)sender;

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *sensorTag;
@property (nonatomic, assign) BOOL keepScanning;

@property int lastGramReading;

@end

@implementation BLEScaleReader {
    BOOL circleDrawn;
}

#pragma mark - Core Data Stuff

//@systhesize is to associate the instance variable with the properties in the interface
@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

#pragma mark - BLE methods

- (void)viewDidLoad {
    [super viewDidLoad];
    // Create the CBCentralManager.
    // NOTE: Creating the CBCentralManager with initWithDelegate will immediately call centralManagerDidUpdateState.
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:nil];
    [[HealthKitManager sharedManager] requestAuthorization];
    
    // configure our initial UI
    self.weightLabel.font = [UIFont fontWithName:@"HelveticaNeue-Thin" size:56];
    self.weightLabel.text = @"Scanning";

    self.lastGramReading = -1;
    circleDrawn = NO;
    self.circleView.hidden = YES;
    [self.view bringSubviewToFront:self.backgroundImageView];
    (self.backgroundImageView).alpha = 1;
    [self.view bringSubviewToFront:self.controlContainerView];
    int cupWeight = [self getCupWeight];
    self.currentCupWeight.text = [NSString stringWithFormat:@" %d grams", (int)cupWeight];
}

- (void)pauseScan {
    // Scanning uses up battery on phone, so pause the scan process for the designated interval.
    NSLog(@"Pausing scan...");
    [NSTimer scheduledTimerWithTimeInterval:RESCAN_WAIT_TIME target:self selector:@selector(resumeScan) userInfo:nil repeats:NO];
    [self.centralManager stopScan];
}

- (void)resumeScan {
    if (self.keepScanning) {
        // Start scanning again...
        NSLog(@"Resume scanning...");
        [NSTimer scheduledTimerWithTimeInterval:BLE_SCAN_INTERVAL target:self selector:@selector(pauseScan) userInfo:nil repeats:NO];
        [self.centralManager scanForPeripheralsWithServices:nil options:nil];
    }
}

- (void)cleanup {
    [_centralManager cancelPeripheralConnection:self.sensorTag];
}


#pragma mark - Updating UI

- (void)displayGrams:(int) grams {
    self.weightLabel.font = [UIFont fontWithName:@"HelveticaNeue-Thin" size:61];
    self.weightLabel.text = [NSString stringWithFormat:@" %d grams", (int)grams];
}

- (void)drawCircle { // Not used
    self.circleView.hidden = NO;
    CAShapeLayer *circleLayer = [CAShapeLayer layer];
    [circleLayer setPath:[[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, self.circleView.bounds.size.width, self.circleView.bounds.size.height)] CGPath]];
    [[self.circleView layer] addSublayer:circleLayer];
    [circleLayer setLineWidth:2];
    [circleLayer setStrokeColor:[UIColor whiteColor].CGColor];
    [circleLayer setFillColor:[UIColor clearColor].CGColor];
    circleDrawn = YES;
}

#pragma mark - CBCentralManagerDelegate methods

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    BOOL showAlert = YES;
    NSString *state = @"";
    switch ([central state])
    {
        case CBCentralManagerStateUnsupported:
            state = @"This device does not support Bluetooth Low Energy.";
            break;
        case CBCentralManagerStateUnauthorized:
            state = @"This app is not authorized to use Bluetooth Low Energy.";
            break;
        case CBCentralManagerStatePoweredOff:
            state = @"Bluetooth on this device is currently powered off.";
            break;
        case CBCentralManagerStateResetting:
            state = @"The BLE Manager is resetting; a state update is pending.";
            break;
        case CBCentralManagerStatePoweredOn:
            showAlert = NO;
            state = @"Bluetooth LE is turned on and ready for communication.";
            NSLog(@"%@", state);
            self.keepScanning = YES;
            [NSTimer scheduledTimerWithTimeInterval:BLE_SCAN_INTERVAL target:self selector:@selector(pauseScan) userInfo:nil repeats:NO];
            [self.centralManager scanForPeripheralsWithServices:nil options:nil];
            break;
        case CBCentralManagerStateUnknown:
            state = @"The state of the BLE Manager is unknown.";
            break;
        default:
            state = @"The state of the BLE Manager is unknown.";
    }
    
    if (showAlert) {
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Central Manager State" message:state preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
        [ac addAction:okAction];
        [self presentViewController:ac animated:YES completion:nil];
    }
    
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    // Retrieve the peripheral name from the advertisement data using the "kCBAdvDataLocalName" key
    NSString *peripheralName = [advertisementData objectForKey:@"kCBAdvDataLocalName"];
    NSLog(@"Next Peripheral: %@ (%@)", peripheralName, peripheral.identifier.UUIDString);
    if ([peripheral.identifier.UUIDString isEqualToString:TARGET_BLE_UUID]) {
        self.keepScanning = NO;
        
        // save a reference to the sensor tag
        self.sensorTag = peripheral;
        self.sensorTag.delegate = self;
        
        // Request a connection to the peripheral
        [self.centralManager connectPeripheral:self.sensorTag options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"Connection successful...");
    self.weightLabel.font = [UIFont fontWithName:@"HelveticaNeue-Thin" size:56];
    self.weightLabel.text = @"Paired";

    // Now that we've successfully connected to the SensorTag, let's discover the services.
    // - NOTE:  we pass nil here to request ALL services be discovered.
    //          If there was a subset of services we were interested in, we could pass the UUIDs here.
    //          Doing so saves batter life and saves time.
    [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Connection failed...");
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Disconnected...");
    self.weightLabel.text = @"Searching";
}


#pragma mark - CBPeripheralDelegate methods

// When the specified services are discovered, the peripheral calls the peripheral:didDiscoverServices: method of its delegate object.
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    // Core Bluetooth creates an array of CBService objects —- one for each service that is discovered on the peripheral.
    for (CBService *service in peripheral.services) {
        NSLog(@"Discovered service: %@", service);
        if (([service.UUID isEqual:[CBUUID UUIDWithString:TARGET_BLE_SERVICE_UUID]])) {
            [peripheral discoverCharacteristics:nil forService:service];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    for (CBCharacteristic *characteristic in service.characteristics) {
        NSLog(@"Discovered characteristic: %@", characteristic);
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TARGET_BLE_CHARACTERISIC_UUID]]) {
            // Enable BLE service notification
            [self.sensorTag setNotifyValue:YES forCharacteristic:characteristic];
            
            // Pair with the BLE scale
            uint8_t enableValue = 1;
            NSData *enableBytes = [NSData dataWithBytes:&enableValue length:sizeof(uint8_t)];
            [self.sensorTag writeValue:enableBytes forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
        }
    }
}


- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error changing notification state: %@", [error localizedDescription]);
        return;
    }
    
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"FFF4"]]) {
        // Extract the data from the characteristic's value property
        // and display the value based on the characteristic type
        NSData *data = characteristic.value;
        
        // Get the two bytes that represent the amount of grams in hex
        NSData *gramsInTwoByte = [data subdataWithRange:NSMakeRange(4,2)];
        
        // Convert the 2 byte hex value to int
        NSMutableString *hexString = [self nsDataToString:gramsInTwoByte];
        int grams = [self hexStringToInt:hexString];
        
        if(self.lastGramReading == grams) {
            // The IDAODAN brand scale sensor sends two notifications for one read.
            // Ignore the second weight reading.
            
            // Reset the last gram reading just in case two reads are
            // exactly the same.  This should be really rare.
            self.lastGramReading = -1;
            return;
        }
                
        self.lastGramReading = grams;
        NSLog(@"*** Grams: %d", grams);
        
        BOOL isCupWeighIn = [self.recordCupWeightSwitch isOn];
        if(isCupWeighIn) {
            // Update UI to show grams
            [self displayGrams:grams];
            // Record cup weight to CoreData
            [self deleteAllObjects:@"CupWeight"]; // make sure we only have one entry for cup weight in database
            [self recordGrams:grams];
            self.currentCupWeight.text = [NSString stringWithFormat:@" %d grams", (int)grams];
        } else {
            int cupWeight = [self getCupWeight];
            int weightWithoutCup = grams - cupWeight;
            // Update UI to show grams
            [self displayGrams:weightWithoutCup];
            
            // Update Health Kit
            [[HealthKitManager sharedManager] writeWaterSample:weightWithoutCup];
            NSLog(@"HealthKit updated with %d mL", weightWithoutCup);
        }
    }
}

- (NSMutableString *) nsDataToString:(NSData *) data {
    NSUInteger dataLength = [data length];
    NSMutableString *stringResult = [NSMutableString stringWithCapacity:dataLength*2];
    const unsigned char *dataBytes = [data bytes];
    for (NSInteger idx = 0; idx < dataLength; ++idx) {
        [stringResult appendFormat:@"%02x", dataBytes[idx]];
    }
    return stringResult;
}

- (int) hexStringToInt:(NSMutableString *) hexString {
    unsigned result;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner scanHexInt:&result];
    return result;
}

#pragma mark - Core Data Methods

- (void)recordGrams:(int) grams {
    // Create Managed Object
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"CupWeight" inManagedObjectContext:self.managedObjectContext];
    NSManagedObject *newSample = [[NSManagedObject alloc] initWithEntity:entityDescription insertIntoManagedObjectContext:self.managedObjectContext];
    [newSample setValue:[NSNumber numberWithInt:grams] forKey:@"grams"];
    
    NSDate *today = [NSDate date];
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"dd/MM/yyyy"];
    //[newSample setValue:today forKey:@"date"];
    
    NSError *error = nil;
    
    if (![newSample.managedObjectContext save:&error]) {
        NSLog(@"Unable to save managed object context.");
        NSLog(@"%@, %@", error, error.localizedDescription);
    }
}

- (int)getCupWeight {
    
    NSManagedObjectContext *moc = self.managedObjectContext;
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"CupWeight"];
    
    NSError *error = nil;
    NSArray *results = [moc executeFetchRequest:request error:&error];
    if (!results) {
        NSLog(@"Error fetching Employee objects: %@\n%@", [error localizedDescription], [error userInfo]);
        abort();
    }
    if([results count] == 0) {
        return 0;
    }
    NSManagedObject *weight = (NSManagedObject *)[results objectAtIndex:0];
    NSNumber *cupWeight = [weight valueForKey:@"grams"];
    NSLog(@"Database has cup weight of %@ grams", cupWeight);
    
    return [cupWeight intValue];
}

-(void)deleteAllObjects: (NSString *)entityName{
    NSFetchRequest *request=[NSFetchRequest fetchRequestWithEntityName:entityName];
    NSError *error;
    NSArray *items =[self.managedObjectContext executeFetchRequest:request error:&error];
    
    for (NSManagedObject *managedObject in items) {
        [self.managedObjectContext deleteObject:managedObject];
    }
    if(![self.managedObjectContext save:&error]){
        NSLog(@"Error deleting: %@ - error: %@",entityName,error);
    }
}

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Core_Data" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Core_Data.sqlite"];
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
         @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES}
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (IBAction)saveCupWeightButton:(id)sender {
    NSLog(@"Button pressed...");
}
@end
