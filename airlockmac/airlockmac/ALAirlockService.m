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

@interface ALAirlockService () <CBPeripheralManagerDelegate, CBPeripheralDelegate> {}
@property BOOL loginwindowIsFrontmostApplication;
@property BOOL screenIsSleeping;
@property (strong, nonatomic) NSTimer *watchFrontmostApplicationTimer;

@property (strong, nonatomic) CBPeripheralManager *iBeaconManager;
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


#pragma mark - BlueTooth Periperal

- (void)startAdvertiseAsiBeacon
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self stopAdvertiseAsiBeacon];
    self.iBeaconManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
}

- (void)stopAdvertiseAsiBeacon
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if ([self.iBeaconManager isAdvertising]) [self.iBeaconManager stopAdvertising];
}

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
        if (peripheral == self.iBeaconManager) {
            [self startAdvertisingIBeacon];
        }

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
    

    CBMutableService* service = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:@"05E23F73-4B0D-4822-BBAD-FC1E00490866"]
                                                               primary:YES];
    service.characteristics = @[characteristic];
    
    self.service = service;
    
    [self.peripheralManager removeAllServices];
    [self.peripheralManager addService:self.service];
}

- (void)startAdvertisingIBeacon
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSUUID *proximityUUID = [[NSUUID alloc] initWithUUIDString:@"74278BDA-B644-4520-8F0C-720EAF059935"];
    
    BLCBeaconAdvertisementData *beaconData = [[BLCBeaconAdvertisementData alloc] initWithProximityUUID:proximityUUID
                                                                                                 major:7
                                                                                                 minor:7031
                                                                                         measuredPower:-64];
    
    [self.peripheralManager startAdvertising:beaconData.beaconAdvertisement];
}

- (void)startAdvertisingPeripheral {
    [self.peripheralManager startAdvertising:@{
                                               CBAdvertisementDataLocalNameKey: @"airlockOSX",
                                               CBAdvertisementDataServiceUUIDsKey: @[[CBUUID UUIDWithString:@"05E23F73-4B0D-4822-BBAD-FC1E00490866"]]
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
}

#pragma mark -
@end
