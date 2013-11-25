//
//  ALDebugOverviewTableViewController.m
//  airlockios
//
//  Created by Tobias Liebig on 25.11.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALDebugOverviewTableViewController.h"
#import <CoreLocation/CoreLocation.h>

@interface ALDebugOverviewTableViewController () <CLLocationManagerDelegate>

@property (nonatomic, strong) IBOutlet UISwitch* switchMonitorIbeacon;
@property (nonatomic, strong) IBOutlet UILabel* labelInRange;
@property (nonatomic, strong) IBOutlet UILabel* labelInProximity;

@property (strong, nonatomic) CLBeaconRegion *beaconRegion;
@property (strong, nonatomic) CLLocationManager *locationManager;

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
    
    [self monitorRegion];
}

# pragma mark -
- (IBAction)switchMonitoring:(id)sender
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self monitorRegion];
}

# pragma mark -
- (void)monitorRegion
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
    
    if (beacon == nil) return;

    if (beacon.proximity == CLProximityUnknown) {
        self.labelInProximity.text = @"Unknown";
        
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

    } else if (beacon.proximity == CLProximityImmediate) {
        self.labelInProximity.text = @"Immediate";
        self.labelInRange.text = @"YES";

    }
    self.lastBeaconProximity = beacon.proximity;
}

- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region
{
    NSLog(@"%s", __PRETTY_FUNCTION__);

    if (state == CLRegionStateInside) {
        UILocalNotification* localNotification = [[UILocalNotification alloc] init];
        localNotification.alertAction = @"AIRLOCK";
        localNotification.alertBody = @"Inside region";
        localNotification.soundName = UILocalNotificationDefaultSoundName;
        [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
    } else if (state == CLRegionStateOutside) {
        UILocalNotification* localNotification = [[UILocalNotification alloc] init];
        localNotification.alertAction = @"AIRLOCK";
        localNotification.alertBody = @"Outside region";
        localNotification.soundName = UILocalNotificationDefaultSoundName;
        [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
        self.labelInRange.text = @"NO";
    }
}

# pragma mark -

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
