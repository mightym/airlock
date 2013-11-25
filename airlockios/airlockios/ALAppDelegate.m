//
//  ALAppDelegate.m
//  airlockios
//
//  Created by Mark Wirblich on 13.11.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALAppDelegate.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreLocation/CoreLocation.h>


@interface ALAppDelegate () <CBPeripheralManagerDelegate, CBPeripheralDelegate, CLLocationManagerDelegate> {}

@property(nonatomic, strong) CBPeripheralManager *peripheralManager;
@property(nonatomic, strong) CBMutableService *service;

@property (strong, nonatomic) CLBeaconRegion *beaconRegion;
@property (strong, nonatomic) CLLocationManager *locationManager;

@end

@implementation ALAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    [self monitorMacBeacon];
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark -

- (void)monitorMacBeacon
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    [self initRegion];
    
    [self locationManager:self.locationManager didStartMonitoringForRegion:self.beaconRegion];
}

- (void)initRegion
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:@"E3DAFC96-5094-4EB9-ADFD-A3A978C8AC19"];
    self.beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:uuid identifier:@"air"];
    [self.locationManager startMonitoringForRegion:self.beaconRegion];
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self.locationManager startRangingBeaconsInRegion:self.beaconRegion];
}

-(void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self.locationManager stopRangingBeaconsInRegion:self.beaconRegion];
}

-(void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    CLBeacon *beacon = [[CLBeacon alloc] init];
    beacon = [beacons lastObject];

    if (beacon.proximity == CLProximityUnknown) {
        NSLog(@"Unknown Proximity");
        [self cancelAdvertiseIOSPeripheral];
    } else if (beacon.proximity == CLProximityImmediate) {
        NSLog(@"Immediate");
        [self advertiseIOSPeripheral];
    } else if (beacon.proximity == CLProximityNear) {
        NSLog(@"Near");
        [self cancelAdvertiseIOSPeripheral];
    } else if (beacon.proximity == CLProximityFar) {
        NSLog(@"Far");
        [self cancelAdvertiseIOSPeripheral];
    }
}

- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self.locationManager startRangingBeaconsInRegion:self.beaconRegion];
}

- (void)cancelAdvertiseIOSPeripheral
{
    [self.peripheralManager removeService:self.service];
    [self.peripheralManager stopAdvertising];
}

- (void)advertiseIOSPeripheral
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (self.peripheralManager) return;
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
}

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (peripheral.state == CBPeripheralManagerStatePoweredOn) {
        [self enablePeripheralService];
    }
}

- (void)enablePeripheralService
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (self.service) {
        [self.peripheralManager removeService:self.service];
    }
    
    self.service = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:@"47FAEEF2-C372-45F7-9E22-BF7A07C22348"]
                                                  primary:YES];
    
    CBMutableCharacteristic *characteristic = [[CBMutableCharacteristic alloc]
                           initWithType:[CBUUID UUIDWithString:@"7E227EED-5A66-4B6C-94E2-B919B27FB722"]
                           properties:CBCharacteristicPropertyNotify
                           value:nil
                           permissions:CBAttributePermissionsReadable];
    
    self.service.characteristics = [NSArray arrayWithObject:characteristic];
    
    [self.peripheralManager addService:self.service];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);

    if (self.peripheralManager.isAdvertising) [self.peripheralManager stopAdvertising];
    
    NSDictionary *advertisment = @{
                                   CBAdvertisementDataLocalNameKey: @"Airlock",
                                   CBAdvertisementDataServiceUUIDsKey: @[[CBUUID UUIDWithString:@"47FAEEF2-C372-45F7-9E22-BF7A07C22348"]]
                                   };
    [self.peripheralManager startAdvertising:advertisment];
}

@end
