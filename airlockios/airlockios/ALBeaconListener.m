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

@property (nonatomic, strong) UILocalNotification *regionNotification;
@property (nonatomic, strong) UILocalNotification *rangingNotification;
@end


@implementation ALBeaconListener

- (id)initWithUUID:(NSUUID *)beaconUUID {
    return [self initWithUUID:beaconUUID major:0 minor:0];
}

- (id)initWithUUID:(NSUUID*)beaconUUID major:(CLBeaconMajorValue)major
{
    return [self initWithUUID:beaconUUID major:major minor:0];
}

- (id)initWithUUID:(NSUUID*)beaconUUID major:(CLBeaconMajorValue)major minor:(CLBeaconMinorValue)minor
{
    self = [super init];
    if (self) {
        self.beaconUUID = beaconUUID;
        self.major = major;
        self.minor = minor;
        self.notified = NO;
        self.locationManager = [[CLLocationManager alloc] init];
    }
    return self;
}

#pragma mark -

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
    [self.locationManager startRangingBeaconsInRegion:self.region];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    NSLog(@"did enter Region %@", region.identifier);
    
    if ([region.identifier isEqualToString:@"com.airlock.ios"]) {
        if (self.regionNotification) {
            [[UIApplication sharedApplication] cancelLocalNotification:self.regionNotification];
            self.regionNotification = nil;
        }
        self.regionNotification = [[UILocalNotification alloc] init];
        self.regionNotification.alertBody = @"You entered the beacon region";
        [[UIApplication sharedApplication] presentLocalNotificationNow:self.regionNotification];

        [manager startRangingBeaconsInRegion:self.region];
    }
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    NSLog(@"did exit Region %@", region.identifier);

    if ([manager.rangedRegions containsObject:region]) {
        if (self.regionNotification) {
            [[UIApplication sharedApplication] cancelLocalNotification:self.regionNotification];
            self.regionNotification = nil;
        }
        self.regionNotification = [[UILocalNotification alloc] init];
        self.regionNotification.alertBody = @"You left the beacon region";
        [[UIApplication sharedApplication] presentLocalNotificationNow:self.regionNotification];

        [manager stopRangingBeaconsInRegion:self.region];
    }
}

- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region
{
    [self.locationManager requestStateForRegion:self.region];
}

- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region
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
        if (self.rangingNotification != nil) {
            [[UIApplication sharedApplication] cancelLocalNotification:self.rangingNotification];
            self.rangingNotification = nil;
        }
        return;
    }

    CLBeacon *firstBeacon = beacons[0];

    switch (firstBeacon.proximity) {
        case CLProximityUnknown:
        {
            NSLog(@"proximity: unknown");
            if (self.rangingNotification != nil) {
                [[UIApplication sharedApplication] cancelLocalNotification:self.rangingNotification];
                self.rangingNotification = nil;
            }
        }
            break;
            
        case CLProximityImmediate:
        {
            NSLog(@"proximity: immediate");

            if (self.rangingNotification == nil) {
                self.rangingNotification = [[UILocalNotification alloc] init];
                self.rangingNotification.alertBody = @"beacon in immediate range";
                [[UIApplication sharedApplication] presentLocalNotificationNow:self.rangingNotification];
            }
        }
            break;
            
        case CLProximityNear:
        {
            NSLog(@"proximity: near");
            if (self.rangingNotification != nil) {
                [[UIApplication sharedApplication] cancelLocalNotification:self.rangingNotification];
                self.rangingNotification = nil;
            }
        }
            break;
            
        case CLProximityFar:
        {
            NSLog(@"proximity: far");
            if (self.rangingNotification != nil) {
                [[UIApplication sharedApplication] cancelLocalNotification:self.rangingNotification];
                self.rangingNotification = nil;
            }
        }
            break;
    }
}


@end
