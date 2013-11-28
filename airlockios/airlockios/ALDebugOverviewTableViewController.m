//
//  ALDebugOverviewTableViewController.m
//  airlockios
//
//  Created by Tobias Liebig on 25.11.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALDebugOverviewTableViewController.h"
#import <CoreLocation/CoreLocation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface ALDebugOverviewTableViewController () <CLLocationManagerDelegate, CBCentralManagerDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate>

@property (nonatomic, strong) IBOutlet UISwitch* switchMonitorIbeacon;
@property (nonatomic, strong) IBOutlet UILabel* labelInRange;
@property (nonatomic, strong) IBOutlet UILabel* labelInProximity;

@property (strong, nonatomic) CLBeaconRegion *beaconRegion;
@property (strong, nonatomic) CLLocationManager *locationManager;

@property (nonatomic, strong) IBOutlet UISwitch* switchMonitorPeripheral;
@property (nonatomic, strong) IBOutlet UILabel* labelStatus;
@property (nonatomic, strong) IBOutlet UILabel* labelName;
@property (nonatomic, strong) IBOutlet UILabel* labelValue;
@property (nonatomic, strong) IBOutlet UILabel* labelRSSI;
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *connectedPeripheral;

@property (nonatomic, strong) IBOutlet UISwitch* switchAdvertisePeripheral;
@property (strong, nonatomic) CBPeripheralManager *peripheralManager;
@property (strong, nonatomic) CBMutableCharacteristic *characteristic;
@property (strong, nonatomic) CBMutableService *service;

@property (nonatomic) NSTimer* rssiUpdateTimer;
@property (nonatomic) CLProximity lastBeaconProximity;

@end

@implementation ALDebugOverviewTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

}

# pragma mark -
- (IBAction)switchMonitoringiBeacon:(id)sender
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self monitoriBeaconRegion];
}

- (IBAction)switchMonitoringPeripheral:(id)sender
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (!self.switchMonitorPeripheral.on) {
        [self.centralManager stopScan];
        if (self.connectedPeripheral) {
            [self.centralManager cancelPeripheralConnection:self.connectedPeripheral];
        }
        
    } else {
        [self discoverAirlockOnMac];
    }
}

- (IBAction)switchAdvertisePeripheral:(id)sender
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (self.switchAdvertisePeripheral.on) {
        [self startAdvertiseAsPeripheral];
    } else {
        [self stopAdvertiseAsPeripheral];
    }
}

# pragma mark -
- (void)monitoriBeaconRegion
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (!self.switchMonitorIbeacon.on) {
        if (self.locationManager != nil) {
            [self.locationManager stopMonitoringForRegion:self.beaconRegion];
        }
        return;
    }

    if (self.locationManager == nil) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        
        NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:@"74278BDA-B644-4520-8F0C-720EAF059935"];
        self.beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:uuid identifier:@"com.wirblich.airlockOSX"];

    }
    
    self.beaconRegion.notifyOnEntry = YES;
    self.beaconRegion.notifyOnExit = YES;
    self.beaconRegion.notifyEntryStateOnDisplay = YES;
    
    [self.locationManager startMonitoringForRegion:self.beaconRegion];
}

# pragma mark - Location Manager

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    self.labelInRange.text = @"YES";
    [self.locationManager startRangingBeaconsInRegion:self.beaconRegion];
}

-(void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    self.labelInRange.text = @"NO";
    [self.locationManager stopRangingBeaconsInRegion:self.beaconRegion];
}

- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self.locationManager startRangingBeaconsInRegion:self.beaconRegion];
}

-(void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region
{
    NSLog(@"%s", __PRETTY_FUNCTION__);

    CLBeacon *beacon = [[CLBeacon alloc] init];
    beacon = [beacons lastObject];
    
    if (beacon == nil) {
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
        return;
    }

    if (beacon.proximity == CLProximityUnknown) {
        self.labelInProximity.text = @"Unknown";
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
        
    } else if (beacon.proximity == CLProximityNear) {
        self.labelInProximity.text = @"Near";
        self.labelInRange.text = @"YES";
        if (self.lastBeaconProximity != CLProximityNear) {
            UILocalNotification* localNotification = [[UILocalNotification alloc] init];
            localNotification.alertAction = @"AIRLOCK";
            localNotification.alertBody = @"Your mac is near";
            localNotification.soundName = UILocalNotificationDefaultSoundName;
            [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
        }
        
    } else if (beacon.proximity == CLProximityFar) {
        self.labelInProximity.text = @"Far";
        self.labelInRange.text = @"YES";
        [[UIApplication sharedApplication] cancelAllLocalNotifications];

    } else if (beacon.proximity == CLProximityImmediate) {
        self.labelInProximity.text = @"Immediate";
        self.labelInRange.text = @"YES";
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
    }
    self.lastBeaconProximity = beacon.proximity;
}

- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region
{
    NSLog(@"%s", __PRETTY_FUNCTION__);

    if (state == CLRegionStateInside) {
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
        UILocalNotification* localNotification = [[UILocalNotification alloc] init];
        localNotification.alertAction = @"AIRLOCK";
        localNotification.alertBody = @"Inside region";
        localNotification.soundName = UILocalNotificationDefaultSoundName;
        [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
    } else if (state == CLRegionStateOutside) {
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
        UILocalNotification* localNotification = [[UILocalNotification alloc] init];
        localNotification.alertAction = @"AIRLOCK";
        localNotification.alertBody = @"Outside region";
        localNotification.soundName = UILocalNotificationDefaultSoundName;
        [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
        self.labelInRange.text = @"NO";
    }
}

#pragma mark -

- (void)discoverAirlockOnMac
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_queue_create("com.wirblich.airlock.cb", NULL) options:nil];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSLog(@"%s %d", __PRETTY_FUNCTION__, (int)central.state);
    if (central.state == CBCentralManagerStatePoweredOn) {
        [self scanForPeripherals];
    }
}

- (void)scanForPeripherals
{
    if (self.switchMonitorPeripheral.on) {
        dispatch_sync(dispatch_get_main_queue(),^{
            self.labelStatus.text = @"scan";
        });
        [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:@"05E23F73-4B0D-4822-BBAD-FC1E00490866"]] options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @YES}];
    }
}

- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"   %@", peripherals);
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"   %@ / %@", peripheral.identifier, peripheral.name);
    NSLog(@"   %d", [RSSI intValue]);

    if (YES) { // [RSSI intValue] > -65) {
        BOOL foundAirlockPeripheral = NO;
        
        NSArray* advertisedServices = (NSArray*)[advertisementData objectForKey:CBAdvertisementDataServiceUUIDsKey];
        for (CBUUID* serviceUuid in advertisedServices) {
            if ([serviceUuid isEqual:[CBUUID UUIDWithString:@"05E23F73-4B0D-4822-BBAD-FC1E00490866"]]) {
                foundAirlockPeripheral = YES;
                break;
            }
        }
        
        if (foundAirlockPeripheral) {
            [self.centralManager stopScan];
            UILocalNotification* localNotification = [[UILocalNotification alloc] init];
            localNotification.alertAction = @"AIRLOCK";
            localNotification.alertBody = [NSString stringWithFormat:@"discover %@", peripheral.name];
            localNotification.soundName = UILocalNotificationDefaultSoundName;
            [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
            
            dispatch_sync(dispatch_get_main_queue(),^{
                self.labelStatus.text = [NSString stringWithFormat:@"found"];
                self.labelName.text = [NSString stringWithFormat:@"%@/%@", [advertisementData objectForKey:CBAdvertisementDataLocalNameKey], peripheral.name];
                self.labelRSSI.text = [NSString stringWithFormat:@"%ld dB", (long)[RSSI integerValue]];
            });
            self.connectedPeripheral = peripheral;
            self.connectedPeripheral.delegate = self;
                        
            [self.centralManager connectPeripheral:self.connectedPeripheral options:nil];

        }
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    dispatch_sync(dispatch_get_main_queue(),^{
        self.labelStatus.text = [NSString stringWithFormat:@"didDisconnect"];
        self.labelValue.text = @"";
        self.labelRSSI.text = @"";
        self.labelName.text = @"";
    });
    self.connectedPeripheral = nil;
    [self scanForPeripherals];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"   %@", error);
    [self scanForPeripherals];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"   %@", peripheral.identifier);

    UILocalNotification* localNotification = [[UILocalNotification alloc] init];
    localNotification.alertAction = @"AIRLOCK";
    localNotification.alertBody = [NSString stringWithFormat:@"connect to %@", peripheral.name];
    localNotification.soundName = UILocalNotificationDefaultSoundName;
    [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];

    dispatch_sync(dispatch_get_main_queue(),^{
        self.labelStatus.text = @"discover service";
    });
    [peripheral discoverServices:@[[CBUUID UUIDWithString:@"05E23F73-4B0D-4822-BBAD-FC1E00490866"]]];
    self.rssiUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateRssiValue:) userInfo:nil repeats:YES];
    self.rssiUpdateTimer.tolerance = 5.0;
}

- (void)updateRssiValue:(NSTimer*)timer
{
    if (self.connectedPeripheral && (self.connectedPeripheral.state == CBPeripheralStateConnecting ||  self.connectedPeripheral.state == CBPeripheralStateConnected)) {
        [self.connectedPeripheral readRSSI];
    } else {
        [self.rssiUpdateTimer invalidate];
        self.rssiUpdateTimer = nil;
    }
}

- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error
{
    dispatch_sync(dispatch_get_main_queue(),^{
        self.labelRSSI.text = [NSString stringWithFormat:@"%ld dB", (long)[peripheral.RSSI integerValue]];
    });
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"   %@", peripheral.services);

    CBService* service;
    for (CBService* availableService in peripheral.services) {
        if ([availableService.UUID isEqual:[CBUUID UUIDWithString:@"05E23F73-4B0D-4822-BBAD-FC1E00490866"]]) {
            service = availableService;
        }
    }
    dispatch_sync(dispatch_get_main_queue(),^{
        self.labelStatus.text = @"discover Characteristics";
    });
    [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:@"482D14E2-DA9A-4795-9841-9DF3F8165259"]] forService:service];

}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"   %@", service.characteristics);
    dispatch_sync(dispatch_get_main_queue(),^{
        self.labelStatus.text = @"read";
    });
    if (service.characteristics.count > 0) {
        NSLog(@"service.characteristics %@", service.characteristics);
        [peripheral readValueForCharacteristic:service.characteristics.lastObject];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    dispatch_sync(dispatch_get_main_queue(),^{
        self.labelStatus.text = @"ready";
        self.labelValue.text = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    });
}



#pragma mark - BlueTooth Periperal

- (void)startAdvertiseAsPeripheral
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self stopAdvertiseAsPeripheral];
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
}

- (void)stopAdvertiseAsPeripheral
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if ([self.peripheralManager isAdvertising]) [self.peripheralManager stopAdvertising];
}


- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    NSLog(@"%s %ld", __PRETTY_FUNCTION__, peripheral.state);
    if (peripheral.state == CBPeripheralManagerStatePoweredOn) {
        if (peripheral == self.peripheralManager) {
            [self enablePeripheralService];
        }
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self startAdvertisingPeripheral];
}

- (void)enablePeripheralService
{
    
    CBMutableCharacteristic* characteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:@"5CFE303E-501A-4C83-AF66-332999CD80F2"]
                                                                                 properties:CBCharacteristicPropertyRead
                                                                                      value:[@"foobar" dataUsingEncoding:NSUTF8StringEncoding]
                                                                                permissions:CBAttributePermissionsReadable];
    
    CBMutableCharacteristic* characteristic1 = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:@"482D14E2-DA9A-4795-9841-9DF3F8165259"]
                                                                                  properties:CBCharacteristicPropertyRead
                                                                                       value:nil
                                                                                 permissions:CBAttributePermissionsReadable];
    
    CBMutableCharacteristic* characteristic2 = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:@"F96637CA-7336-4F15-9D6E-B13A896C95E7"]
                                                                                  properties:CBCharacteristicPropertyWrite
                                                                                       value:nil
                                                                                 permissions:CBAttributePermissionsWriteable];
    
    CBMutableCharacteristic* characteristic3 = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:@"F310D252-5E00-4DF9-BAE8-459FB63743D2"]
                                                                                  properties:CBCharacteristicPropertyWrite
                                                                                       value:nil
                                                                                 permissions:CBAttributePermissionsWriteEncryptionRequired];
    
    CBMutableCharacteristic* characteristic4 = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:@"15D80DE8-B700-42FF-AB00-4FA6258EBCBA"]
                                                                                  properties:CBCharacteristicPropertyWriteWithoutResponse
                                                                                       value:nil
                                                                                 permissions:CBAttributePermissionsWriteable];
    
    CBMutableService* service = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:@"0A8446F2-93EA-4587-8AC1-CC24B3D9BA2E"]
                                                               primary:YES];
    service.characteristics = @[characteristic, characteristic1, characteristic2, characteristic3, characteristic4];
    
    self.service = service;
    
    if (self.peripheralManager.isAdvertising) [self.peripheralManager stopAdvertising];
    [self.peripheralManager removeAllServices];
    [self.peripheralManager addService:self.service];
}

- (void)startAdvertisingPeripheral {
    [self.peripheralManager startAdvertising:@{
                                               CBAdvertisementDataLocalNameKey: @"airlockIOS",
                                               CBAdvertisementDataServiceUUIDsKey: @[[CBUUID UUIDWithString:@"0A8446F2-93EA-4587-8AC1-CC24B3D9BA2E"]]
                                               }];
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (error) NSLog(@"%@", error);
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"%@", characteristic.value);
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"  %@", request.central.identifier);
    
    
    if ([request.characteristic.UUID isEqual:[CBUUID UUIDWithString:@"482D14E2-DA9A-4795-9841-9DF3F8165259"]]) {
        
        NSData *value = [[[NSDate date] description] dataUsingEncoding:NSUTF8StringEncoding];
        if (request.offset > value.length) {
            [peripheral respondToRequest:request withResult:CBATTErrorInvalidOffset];
            return;
        }
        
        request.value = [value subdataWithRange:NSMakeRange(request.offset, MIN(value.length - request.offset, 20))];
        [peripheral respondToRequest:request withResult:CBATTErrorSuccess];
//    [peripheral respondToRequest:request withResult:CBATTErrorInsufficientAuthentication];
        return;
    }
    
    [peripheral respondToRequest:request withResult:CBATTErrorRequestNotSupported];
    
    return;
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests
{
    for (CBATTRequest* request in requests) {
        NSLog(@"request.value: %@ (for %@)", [[NSString alloc] initWithData:request.value encoding:NSUTF8StringEncoding], request.characteristic.UUID);
        [peripheral respondToRequest:request withResult:CBATTErrorSuccess];
    }
}

#pragma mark -

# pragma mark -

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
