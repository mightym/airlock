//
//  ALAirlockService.m
//  airlockmac
//
//  Created by Tobias Liebig on 18.11.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALAirlockService.h"
#import "ALAppDelegate.h"
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#import <IOBluetooth/IOBluetooth.h>
#import "BLCBeaconAdvertisementData.h"

@interface ALAirlockService () <CBPeripheralManagerDelegate, CBCentralManagerDelegate, CBPeripheralDelegate> {}
@property BOOL loginwindowIsFrontmostApplication;
@property BOOL screenIsSleeping;
@property (strong, nonatomic) NSTimer *watchFrontmostApplicationTimer;
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *connectedPeripheral;

@property (strong, nonatomic) CBPeripheralManager *peripheralManager;
@property (strong, nonatomic) CBMutableCharacteristic *characteristic;
@property (strong, nonatomic) CBMutableService *service;

@end

@implementation ALAirlockService

#pragma mark - life cycle

+ (instancetype)sharedService
{
    static ALAirlockService *_sharedService = nil;
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
        self.loginwindowIsFrontmostApplication = NO;
        self.screenIsSleeping = YES;
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()]; // TODO use another queue?
    }
    return self;
}

#pragma mark - Monitoring

- (void)startMonitoring
{
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(receiveSleepNotifiation:) name:NSWorkspaceScreensDidSleepNotification object:NULL];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(receiveWakeNotifiation:) name:NSWorkspaceScreensDidWakeNotification object:NULL];
    
    self.watchFrontmostApplicationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(fireWatchFrontmostApplicationTimer:) userInfo:nil repeats:YES];
    [self.watchFrontmostApplicationTimer setTolerance:1.0];
}

- (void)stopMonitoring
{
    [self.watchFrontmostApplicationTimer invalidate];
    self.watchFrontmostApplicationTimer = nil;
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
}


- (void)fireWatchFrontmostApplicationTimer:(NSTimer*)theTimer
{

    if (self.screenIsSleeping) return;
    
    if ([[[[NSWorkspace sharedWorkspace] frontmostApplication] bundleIdentifier] isEqualToString:@"com.apple.loginwindow"]) {
        if (!self.loginwindowIsFrontmostApplication
            && self.loginwindowDidBecomeFrontmostApplicationBlock) {
                self.loginwindowDidBecomeFrontmostApplicationBlock();
        }
        self.loginwindowIsFrontmostApplication = YES;
    } else {
        if (self.loginwindowIsFrontmostApplication
            && self.loginwindowDidResignFrontmostApplicationBlock) {
            self.loginwindowDidResignFrontmostApplicationBlock();
        }
        self.loginwindowIsFrontmostApplication = NO;
    }
}

- (void)receiveSleepNotifiation:(NSNotification*)notification
{
    self.screenIsSleeping = YES;
}

- (void)receiveWakeNotifiation:(NSNotification*)notification
{
    self.screenIsSleeping = NO;
}


#pragma mark - login

- (void)loginUser
{
    if (self.screenIsSleeping) return;
    
    ALAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[NSAppleScript alloc] initWithSource:
     [NSString stringWithFormat:@"say \"login\"\ntell application \"System Events\"\n keystroke \"%@\"\nkeystroke return\nend tell", [appDelegate userPassword]]]
     executeAndReturnError:nil];
}


#pragma mark - lock screen

- (void)lockScreen
{
    if (self.screenIsSleeping) return;
    
    int screenSaverDelayUserSetting = 0;
    
    screenSaverDelayUserSetting = [self readScreensaveDelay];
    
    if (screenSaverDelayUserSetting != 0) {
        // if the delay isn't already 0, temporarily set it to 0 so the screen locks immediately.
        [self setScreensaverDelay:0];
        [self touchSecurityPreferences];
    }
    
    io_registry_entry_t r = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/IOResources/IODisplayWrangler");
    if (r) {
        IORegistryEntrySetCFProperty(r, CFSTR("IORequestIdle"), sleep ? kCFBooleanTrue : kCFBooleanFalse);
        IOObjectRelease(r);
    }
    
    if (screenSaverDelayUserSetting != 0) {
        [self setScreensaverDelay:screenSaverDelayUserSetting];
        [self launchAndQuitSecurityPreferences];
    }
}

- (void)touchSecurityPreferences
{
    // necessary for screen saver setting changes to take effect on file-vault-enabled systems
    // NOTE: this *only* works when going from non-zero settings of askForPasswordDelay to zero.
    
    NSAppleScript *kickSecurityPreferencesScript = [[NSAppleScript alloc] initWithSource: @"tell application \"System Events\" to tell security preferences to set require password to wake to true"];
    [kickSecurityPreferencesScript executeAndReturnError:nil];
}

- (void)launchAndQuitSecurityPreferences
{
    // necessary for screen saver setting changes to take effect on file-vault-enabled systems when going from a askForPasswordDelay setting of zero to a non-zero setting
    NSAppleScript *kickSecurityPreferencesScript = [[NSAppleScript alloc] initWithSource:
                                                    @"tell application \"System Preferences\"\n"
                                                    @"     tell anchor \"General\" of pane \"com.apple.preference.security\" to reveal\n"
                                                    @"     activate\n"
                                                    @"end tell\n"
                                                    @"delay 0\n"
                                                    @"tell application \"System Preferences\" to quit"];
    [kickSecurityPreferencesScript executeAndReturnError:nil];
}

- (int)readScreensaveDelay
{
    NSArray *arguments = @[@"read",@"com.apple.screensaver",@"askForPasswordDelay"];
    
    NSTask *readDelayTask = [[NSTask alloc] init];
    [readDelayTask setArguments:arguments];
    [readDelayTask setLaunchPath: @"/usr/bin/defaults"];
    
    NSPipe *pipe = [NSPipe pipe];
    [readDelayTask setStandardOutput:pipe];
    NSFileHandle *file = [pipe fileHandleForReading];
    [readDelayTask launch];
    NSData *resultData = [file readDataToEndOfFile];
    NSString *resultString = [[NSString alloc] initWithData:resultData encoding:NSUTF8StringEncoding];
    return resultString.intValue;
}

- (void)setScreensaverDelay:(int)delay
{
    NSArray *arguments = @[@"write",@"com.apple.screensaver",@"askForPasswordDelay", [NSString stringWithFormat:@"%i", delay]];
    NSTask *resetDelayTask = [[NSTask alloc] init];
    [resetDelayTask setArguments:arguments];
    [resetDelayTask setLaunchPath: @"/usr/bin/defaults"];
    [resetDelayTask launch];
}

#pragma mark - BlueTooth Central

- (void)monitorForDevice
{
    if (self.centralManager.state != CBCentralManagerStatePoweredOn) {
        NSLog(@"Defer scanning until manager comes online");
        return;
    }

    NSDictionary *scanningOptions = @{ CBCentralManagerScanOptionAllowDuplicatesKey : @NO };
    [self.centralManager scanForPeripheralsWithServices:nil
                                    options:scanningOptions];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSLog(@"centralManagerDidUpdateState: state %ld", central.state);
    if (central.state == CBCentralManagerStatePoweredOn) {
        [self monitorForDevice];
    }
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
    if (peripheral.name == nil || [peripheral.name isEqualToString:@"estimote"]) return;
    NSLog(@"didDiscoverPeripheral: -------------------------------------------------");
    NSLog(@"didDiscoverPeripheral: Peripheral identifier: %@ %@ %@", peripheral.identifier, peripheral.name, RSSI);
    NSArray* serviceUuids = [advertisementData objectForKey:CBAdvertisementDataServiceUUIDsKey];
    NSLog(@"%@", serviceUuids);
    if ([serviceUuids containsObject:@"47FAEEF2-C372-45F7-9E22-BF7A07C22348"]) {
        NSLog(@"Here we are!");
    }
    
    /*
    if ([peripheral.identifier isEqualTo:[[NSUUID alloc] initWithUUIDString:@"125647CD-F0EF-4ECF-A9B2-2CC1E323B158"]]) {
        [self.manager stopScan];
        self.connectedPeripheral = peripheral;
        NSLog(@"connect %@", peripheral);
        [self.manager connectPeripheral:self.connectedPeripheral options:nil];
    }
     */
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"didConnectPeripheral: Peripheral identifier: %@", peripheral.identifier);
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"didFailToConnectPeripheral %@", error);
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    for (CBService *service in peripheral.services) {
        NSLog(@"Service: %@", service.UUID);
    }
}
#pragma mark - BlueTooth Periperal

- (void)advertiseAsiBeacon
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
}

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (peripheral.state == CBPeripheralManagerStatePoweredOn) {
        [self enableService];
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral
            didAddService:(CBService *)service
                    error:(NSError *)error {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self startAdvertising];
}

- (void)enableService
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (self.service) {
        [self.peripheralManager removeService:self.service];
    }

    self.service = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:@"1E960C29-5247-44E7-BEEE-A91FBC21454F"]
                                                  primary:YES];
    
    self.characteristic = [[CBMutableCharacteristic alloc]
                           initWithType:[CBUUID UUIDWithString:@"2ABFE74D-52E2-47FD-A574-B7FECB3EE8AF"]
                           properties:CBCharacteristicPropertyWriteWithoutResponse
                           value:nil
                           permissions:0];
    
    self.service.characteristics = [NSArray arrayWithObject:self.characteristic];
    
    [self.peripheralManager addService:self.service];
}

- (void)startAdvertising
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSUUID *proximityUUID = [[NSUUID alloc] initWithUUIDString:@"E3DAFC96-5094-4EB9-ADFD-A3A978C8AC19"];
    
    BLCBeaconAdvertisementData *beaconData = [[BLCBeaconAdvertisementData alloc] initWithProximityUUID:proximityUUID
                                                                                                 major:1
                                                                                                 minor:1
                                                                                         measuredPower:-58];
    
    [self.peripheralManager startAdvertising:beaconData.beaconAdvertisement];
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"%@", characteristic.value);
}

#pragma mark -
@end
