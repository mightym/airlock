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

@interface ALAirlockService () <CBCentralManagerDelegate, CBPeripheralManagerDelegate, CBPeripheralDelegate> {}
@property BOOL loginwindowIsFrontmostApplication;
@property BOOL screenIsSleeping;
@property (strong, nonatomic) NSTimer *watchFrontmostApplicationTimer;

@property (strong, nonatomic) CBPeripheralManager *iBeaconManager;
@property (strong, nonatomic) CBPeripheralManager *peripheralManager;
@property (strong, nonatomic) CBMutableCharacteristic *characteristic;
@property (strong, nonatomic) CBMutableService *service;

@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *connectedPeripheral;
@property (nonatomic) NSTimer* rssiUpdateTimer;

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
    
    CBMutableService* service = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:@"05E23F73-4B0D-4822-BBAD-FC1E00490866"]
                                                               primary:YES];
    service.characteristics = @[characteristic, characteristic1, characteristic2, characteristic3, characteristic4];
    
    self.service = service;
    
    if (self.peripheralManager.isAdvertising) [self.peripheralManager stopAdvertising];
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
    
    [peripheral respondToRequest:request withResult:CBATTErrorInsufficientAuthentication];
    return;
    
    if ([request.characteristic.UUID isEqual:[CBUUID UUIDWithString:@"482D14E2-DA9A-4795-9841-9DF3F8165259"]]) {
        
        NSData *value = [[[NSDate date] description] dataUsingEncoding:NSUTF8StringEncoding];
        if (request.offset > value.length) {
            [peripheral respondToRequest:request withResult:CBATTErrorInvalidOffset];
            return;
        }

        request.value = [value subdataWithRange:NSMakeRange(request.offset, MIN(value.length - request.offset, 20))];
        [peripheral respondToRequest:request withResult:CBATTErrorSuccess];
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

#pragma mark - Bluetooth Central

- (void)discoverAirlockOnIOS
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:nil]; // dispatch_queue_create("com.wirblich.airlock.cb", NULL)
}

- (void)stopDiscoverAirlockOnIOS
{
    if (self.centralManager.state == CBCentralManagerStatePoweredOn) [self.centralManager stopScan];
    if (self.connectedPeripheral) {
        [self.centralManager cancelPeripheralConnection:self.connectedPeripheral];
    }
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
    NSLog(@"%s", __PRETTY_FUNCTION__);
//    [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:@"0A8446F2-93EA-4587-8AC1-CC24B3D9BA2E"]] options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @YES}];
    [self.centralManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @YES}];
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
//    NSLog(@"   %d", [RSSI intValue]);
    
    if (YES) { // [RSSI intValue] > -65) {
        BOOL foundAirlockPeripheral = NO;
        
        NSArray* advertisedServices = (NSArray*)[advertisementData objectForKey:CBAdvertisementDataServiceUUIDsKey];
        for (CBUUID* serviceUuid in advertisedServices) {
            NSLog(@"%@", serviceUuid);
            if ([serviceUuid isEqual:[CBUUID UUIDWithString:@"0A8446F2-93EA-4587-8AC1-CC24B3D9BA2E"]]) {
                foundAirlockPeripheral = YES;
                break;
            }
        }
        
        if (foundAirlockPeripheral) {
            [self.centralManager stopScan];
            
            NSLog(@"%@", [NSString stringWithFormat:@"%@/%@", [advertisementData objectForKey:CBAdvertisementDataLocalNameKey], peripheral.name]);
            NSLog(@"%@", [NSString stringWithFormat:@"%ld dB", (long)[RSSI integerValue]]);
            self.connectedPeripheral = peripheral;
            self.connectedPeripheral.delegate = self;
            
            [self.centralManager connectPeripheral:self.connectedPeripheral options:nil];
            
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
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
    
    [peripheral discoverServices:@[[CBUUID UUIDWithString:@"0A8446F2-93EA-4587-8AC1-CC24B3D9BA2E"]]];
/*
    self.rssiUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateRssiValue:) userInfo:nil repeats:YES];
    self.rssiUpdateTimer.tolerance = 5.0;
 */
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
    NSLog(@"%@", [NSString stringWithFormat:@"%ld dB", (long)[peripheral.RSSI integerValue]]);
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"   %@", peripheral.services);
    
    CBService* service;
    for (CBService* availableService in peripheral.services) {
        if ([availableService.UUID isEqual:[CBUUID UUIDWithString:@"0A8446F2-93EA-4587-8AC1-CC24B3D9BA2E"]]) {
            service = availableService;
        }
    }
    if (service != nil)
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:@"482D14E2-DA9A-4795-9841-9DF3F8165259"]] forService:service];
    
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"   %@", service.characteristics);
    if (service.characteristics.count > 0) {
        [peripheral readValueForCharacteristic:service.characteristics.lastObject];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"   error %@", error);
    NSLog(@"   value %@", [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding]);
}

#pragma mark -


@end
