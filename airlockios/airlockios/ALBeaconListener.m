//
//  ALBeaconListener.m
//  airlockios
//
//  Created by Tobias Liebig on 26.02.14.
//  Copyright (c) 2014 Mark Wirblich. All rights reserved.
//

#import "ALBeaconListener.h"

@interface ALBeaconListener () <CLLocationManagerDelegate>
@property (nonatomic, strong) NSUUID* beaconUUID;
@property (nonatomic, strong) CLLocationManager* locationManager;
@property (nonatomic, strong) CLBeaconRegion *region;
@property CLBeaconMajorValue major;
@property CLBeaconMinorValue minor;
@property BOOL notified;
@end


@implementation ALBeaconListener

- (id)initWithUUID:(NSUUID *)beaconUUID {
    return [self initWithUUID:beaconUUID major:-1 minor:-1];
}

- (id)initWithUUID:(NSUUID*)theBeaconUUID major:(CLBeaconMajorValue)major minor:(CLBeaconMinorValue)minor
{
    self = [super init];
    if (self) {
        self.beaconUUID = theBeaconUUID;
        self.major = major;
        self.minor = minor;
        self.notified = NO;
        self.locationManager = [[CLLocationManager alloc] init];
    }
    return self;
}

- (void)start
{
    // setup beacon region
    if (self.major > 0 && self.minor > 0) {
        self.region = [[CLBeaconRegion alloc] initWithProximityUUID:self.beaconUUID
                                                              major:self.major
                                                              minor:self.minor
                                                         identifier:@"com.airlock.ios"];
    } else if (self.major > 0) {
        self.region = [[CLBeaconRegion alloc] initWithProximityUUID:self.beaconUUID
                                                              major:self.major
                                                         identifier:@"com.airlock.ios"];
    } else {
        self.region = [[CLBeaconRegion alloc] initWithProximityUUID:self.beaconUUID
                                                         identifier:@"com.airlock.ios"];
    }

    self.region.notifyEntryStateOnDisplay = YES;
    self.region.notifyOnEntry = YES;
    self.region.notifyOnExit = YES;
    
    // monitor for region
    self.locationManager.delegate = self;
    [self.locationManager startMonitoringForRegion:self.region];
    
    // might improve detection delay, when immediately starting to range the region:
    //    [self.locationManager startRangingBeaconsInRegion:self.region];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    NSLog(@"did enter Region %@", region.identifier);
    
    if ([region.identifier isEqualToString:@"com.airlock.ios"]) {
        [manager startRangingBeaconsInRegion:self.region];
    }
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    NSLog(@"did exit Region %@", region.identifier);

    if ([manager.rangedRegions containsObject:region]) {
        [manager stopRangingBeaconsInRegion:self.region];
    }
}

- (void) locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region
{
    [self.locationManager requestStateForRegion:self.region];
}

- (void) locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region
{
    switch (state) {
        case CLRegionStateInside:
            NSLog(@"inside beacon region");
            [self.locationManager startRangingBeaconsInRegion:self.region];
            break;
            
        case CLRegionStateOutside:
        case CLRegionStateUnknown:
        default:
            NSLog(@"outside beacon region");
            [self.locationManager stopRangingBeaconsInRegion:self.region];
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"error %@", error);
}



- (void)locationManager:(CLLocationManager *)manager
        didRangeBeacons:(NSArray *)beacons
               inRegion:(CLBeaconRegion *)region {
    if ([beacons count] == 0) {
        NSLog(@"No Beacons in range");
        [UIApplication sharedApplication].applicationIconBadgeNumber = -1;
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
        return;
    }

    CLBeacon *firstBeacon = beacons[0];

    switch (firstBeacon.proximity) {
        case CLProximityUnknown:
        {
            NSLog(@"proximity: unknown");
            self.notified = NO;
            
            [[UIApplication sharedApplication] cancelAllLocalNotifications];
            
            [UIApplication sharedApplication].applicationIconBadgeNumber = -1;
        }
            break;
            
        case CLProximityImmediate:
        {
            NSLog(@"proximity: immediate");

            if (!self.notified) {
                self.notified = YES;
                UILocalNotification *localNotification = [[UILocalNotification alloc] init];
                localNotification.alertBody = @"beacon in immediate range";
                localNotification.applicationIconBadgeNumber = 1;
                [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
            }
        }
            break;
            
        case CLProximityNear:
        {
            NSLog(@"proximity: near");
            self.notified = NO;
            
            [[UIApplication sharedApplication] cancelAllLocalNotifications];
            
            [UIApplication sharedApplication].applicationIconBadgeNumber = 2;
        }
            break;
            
        case CLProximityFar:
        {
            NSLog(@"proximity: far");
            self.notified = NO;
            
            [[UIApplication sharedApplication] cancelAllLocalNotifications];
            
            [UIApplication sharedApplication].applicationIconBadgeNumber = 3;
        }
            break;
    }
}


@end
