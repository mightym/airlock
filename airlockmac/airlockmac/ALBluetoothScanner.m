//
//  ALBluetoothScanner.m
//  airlockmac
//
//  Created by Tobias Liebig on 18.12.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALBluetoothScanner.h"
#import "ALDiscoveredDevice.h"

NSString *const kALNotificationsBluetoothServiceDidFoundNewDeviceNotification = @"kALNotificationsBluetoothServiceDidFoundNewDeviceNotification";
NSString *const kALNotificationsBluetoothServiceDeviceDisappearedNotification = @"kALNotificationsBluetoothServiceDeviceDisappearedNotification";

@interface ALBluetoothScanner ()

@property BOOL isScanningForPeripherals;

@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) NSTimer *checkDisappearedDevicesTimer;

@end

@implementation ALBluetoothScanner

#pragma mark - life cycle

+ (instancetype)sharedService
{
    static ALBluetoothScanner *_sharedService = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedService = [[self alloc] init];
    });
    
    return _sharedService;
}

-(id)init
{
    self = [super init];
    if (self) {
        self.isScanningForPeripherals = NO;
    }
    return self;
}

#pragma mark - public API

-(void)startScanning
{
    if (self.isScanningForPeripherals) return;
    self.isScanningForPeripherals = YES;
    
    if (self.centralManager == nil) {
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                                   queue:dispatch_queue_create("com.wirblich.airlock.cb", NULL)
                                                                 options:nil];
    } else {
        [self centralManagerDidUpdateState:self.centralManager];
    }
}


-(void)stopScanning
{
            NSLog(@"%s", __PRETTY_FUNCTION__);
    if (!self.isScanningForPeripherals) return;
    self.isScanningForPeripherals = NO;
    
    if (self.centralManager) {
        [self.centralManager stopScan];
    }
    if (self.checkDisappearedDevicesTimer != nil) {
        [self.checkDisappearedDevicesTimer invalidate];
        self.checkDisappearedDevicesTimer = nil;
    }
}

#pragma mark - CBCentralManagerDelegate


- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state) {
        case CBCentralManagerStatePoweredOn:
            [self discoverPeripherals];
            break;
            
        default:
            break;
    }
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
    ALDiscoveredDevice *discoveredDevice;
    discoveredDevice = [self.discovered objectForKey:peripheral.identifier];

    if (discoveredDevice == nil) {
        discoveredDevice = [[ALDiscoveredDevice alloc] init];
        discoveredDevice.identifier = peripheral.identifier;
        discoveredDevice.peripheral = peripheral;
        discoveredDevice.lastRSSI = RSSI;
        discoveredDevice.lastSeen = [NSDate date];
        
        [self.discovered setObject:discoveredDevice forKey:peripheral.identifier];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:kALNotificationsBluetoothServiceDidFoundNewDeviceNotification
                                                                object:self
                                                              userInfo:@{@"newDevice": discoveredDevice}];
        });
    } else {
        discoveredDevice.lastRSSI = RSSI;
        discoveredDevice.lastSeen = [NSDate date];
    }
}

#pragma mark -


- (void)discoverPeripherals
{
        NSLog(@"%s", __PRETTY_FUNCTION__);
    self.discovered = [NSMutableDictionary dictionary];
    [self.centralManager scanForPeripheralsWithServices:nil
                                                options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @YES}];
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        self.checkDisappearedDevicesTimer = [NSTimer scheduledTimerWithTimeInterval:2
                                                                             target:self
                                                                           selector:@selector(checkDisappearedDevicesTimerFired:)
                                                                           userInfo:nil
                                                                            repeats:YES];
        self.checkDisappearedDevicesTimer.tolerance = 1.0;
    });
}

- (void)checkDisappearedDevicesTimerFired:(NSTimer*)timer
{
    NSLog(@"checkDisappearedDevicesTimerFired");
    for (ALDiscoveredDevice* device in [self.discovered allValues]) {
        if ([device.lastSeen timeIntervalSinceNow] < -3.0) {
            [self.discovered removeObjectForKey:device.identifier];
            
                [[NSNotificationCenter defaultCenter] postNotificationName:kALNotificationsBluetoothServiceDeviceDisappearedNotification
                                                                    object:self
                                                                  userInfo:@{@"identifier": device.identifier}];
        }
    }
}




@end
