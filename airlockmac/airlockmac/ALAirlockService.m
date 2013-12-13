//
//  ALAirlockService.m
//  airlockmac
//
//  Created by Tobias Liebig on 18.11.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOBluetooth/IOBluetooth.h>
#import <CommonCrypto/CommonDigest.h>

#import "ALAirlockService.h"
#import "ALAppDelegate.h"

#define kALServiceUUID @"0A84"
#define kALCharacteristicDeviceNameUUID @"5CFE"
#define kALCharacteristicWriteChallengeUUID @"482D"
#define kALCharacteristicReadChallengeUUID @"F966"
#define kALChallengeSecret @"FBC29689-D890-4DCD-A7D2-41A95CAFBB5D"


@interface ALAirlockService () <CBCentralManagerDelegate, CBPeripheralDelegate> {}

@property (nonatomic, copy) void (^loginwindowDidBecomeFrontmostApplicationBlock)(void);
@property (nonatomic, copy) void (^loginwindowDidResignFrontmostApplicationBlock)(void);

@property (nonatomic, copy) void (^connectedPeripheralLeavesRange)(void);
@property (nonatomic, copy) void (^connectedPeripheralEntersRange)(void);

@property BOOL loginwindowIsFrontmostApplication;
@property BOOL screenIsSleeping;
@property (strong, nonatomic) NSTimer *watchFrontmostApplicationTimer;

@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *connectedPeripheral;
@property (strong, nonatomic) NSUUID *lastConnectedPeripheralIdentifier;
@property (nonatomic) NSTimer* rssiUpdateTimer;

@property BOOL isScanningForPeripherals;
@property (strong, nonatomic) NSMutableArray *peripheralsToCheck;
@property (strong, nonatomic) NSMutableArray *ignorePeripheralIdentifiers;
@property BOOL peripheralIsNearby;

@property (nonatomic, strong) NSMutableDictionary* discoveredPeripherals;
@property (nonatomic, strong) NSString* responseValueBuffer;
@property (nonatomic, strong) NSString* incomingChallenge;
@property (nonatomic, strong) NSString* outgoingChallenge;

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
        self.screenIsSleeping = NO;
        self.isScanningForPeripherals = NO;
        self.peripheralIsNearby = NO;
        self.discoveredPeripherals = [NSMutableDictionary dictionary];
        self.ignorePeripheralIdentifiers =[NSMutableArray array];
    }
    return self;
}

# pragma mark - API
- (void)startWithDelegate:(id<ALAirlockServiceDelegate>)theDelegate;
{
    self.delegate = theDelegate;
    [self startLockMonitoring];
    [self startPeripheralMonitoring];
    // connect/monitor device
    // montior lock status
}

- (void)stop
{
    [self stopLockMonitoring];
    [self stopPeripheralMonitoring];
}

# pragma mark - helper

- (void)say:(NSString*)words
{
    [[[NSAppleScript alloc] initWithSource:
      [NSString stringWithFormat:@"say \"%@\"", words]]
     executeAndReturnError:nil];
}

#pragma mark - lock status monitoring

- (void)startLockMonitoring
{
    __block ALAirlockService* blockSafeSelf = self;
    [self setLoginwindowDidBecomeFrontmostApplicationBlock:^{
        if ([blockSafeSelf.delegate respondsToSelector:@selector(airlockServiceLoginwindowDidBecomeFrontmostApplication:)])
            [blockSafeSelf.delegate airlockServiceLoginwindowDidBecomeFrontmostApplication:blockSafeSelf];
    }];
    
    [self setLoginwindowDidResignFrontmostApplicationBlock:^{
        if ([blockSafeSelf.delegate respondsToSelector:@selector(airlockServiceLoginwindowDidResignFrontmostApplication:)])
            [blockSafeSelf.delegate airlockServiceLoginwindowDidResignFrontmostApplication:blockSafeSelf];
    }];
    
    [self setConnectedPeripheralEntersRange:^{
        [blockSafeSelf performLogin];
    }];
    [self setConnectedPeripheralLeavesRange:^{
        [blockSafeSelf performLockScreen];
    }];

    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(receiveSleepNotifiation:)
                                                               name:NSWorkspaceScreensDidSleepNotification
                                                             object:NULL];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(receiveWakeNotifiation:)
                                                               name:NSWorkspaceScreensDidWakeNotification
                                                             object:NULL];
    
    self.watchFrontmostApplicationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                                           target:self
                                                                         selector:@selector(fireWatchFrontmostApplicationTimer:) userInfo:nil
                                                                          repeats:YES];
    [self.watchFrontmostApplicationTimer setTolerance:1.0];
}

- (void)stopLockMonitoring
{
    self.loginwindowDidBecomeFrontmostApplicationBlock = nil;
    self.loginwindowDidResignFrontmostApplicationBlock = nil;
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
        [self.watchFrontmostApplicationTimer setTolerance:1.0];
    } else {
        if (self.loginwindowIsFrontmostApplication
            && self.loginwindowDidResignFrontmostApplicationBlock) {
            self.loginwindowDidResignFrontmostApplicationBlock();
        }
        self.loginwindowIsFrontmostApplication = NO;
        [self.watchFrontmostApplicationTimer setTolerance:5.0];
    }
}

- (void)receiveSleepNotifiation:(NSNotification*)notification
{
    self.screenIsSleeping = YES;
}

- (void)receiveWakeNotifiation:(NSNotification*)notification
{
    self.screenIsSleeping = NO;
    if (self.watchFrontmostApplicationTimer) {
        [self fireWatchFrontmostApplicationTimer:self.watchFrontmostApplicationTimer];
    }
    if (self.peripheralIsNearby) {
        [self performConnectedPeripheralEntersRange];
    }
}

- (void)performConnectedPeripheralEntersRange
{
    if (self.connectedPeripheralEntersRange) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(performConnectedPeripheralLeavesRange) object:nil];
        self.connectedPeripheralEntersRange();
    }
}

- (void)performConnectedPeripheralLeavesRange
{
    if (self.connectedPeripheralLeavesRange) {
        self.connectedPeripheralLeavesRange();
    }
}


#pragma mark - login

- (void)performLogin
{
    if (self.screenIsSleeping
        || !self.loginwindowIsFrontmostApplication
        || !self.peripheralIsNearby
        || [self.password isEqualToString:@""]) return;
    
    NSLog(@"login");
    
    [[[NSAppleScript alloc] initWithSource:
     [NSString stringWithFormat:@"tell application \"System Events\"\n keystroke \"%@\"\nkeystroke return\nend tell",
        self.password]]
     executeAndReturnError:nil];
}


#pragma mark - lock screen

- (void)performLockScreen
{
    if (self.screenIsSleeping || self.loginwindowIsFrontmostApplication) return;
    if ([self.password isEqualToString:@""]) {
        NSLog(@"Do not lock; no password given.");
        return;
    }
    
    NSLog(@"lock screen");
    
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
    [[[NSAppleScript alloc]
      initWithSource:@"tell application \"System Events\" to tell security preferences to set require password to wake to true"]
     executeAndReturnError:nil];
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
    NSArray *arguments = @[@"read", @"com.apple.screensaver", @"askForPasswordDelay"];
    
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
    NSArray *arguments = @[@"write", @"com.apple.screensaver", @"askForPasswordDelay", [NSString stringWithFormat:@"%i", delay]];
    NSTask *resetDelayTask = [[NSTask alloc] init];
    [resetDelayTask setArguments:arguments];
    [resetDelayTask setLaunchPath: @"/usr/bin/defaults"];
    [resetDelayTask launch];
}


#pragma mark - bluetooth device monitoring

- (void)startPeripheralMonitoring
{
    if (self.centralManager == nil) {
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                                   queue:nil // dispatch_queue_create("com.wirblich.airlock.cb", NULL)
                                                                 options:nil];
    } else {
        [self findAndConnectAirlockPeripheral];
    }
}

- (void)stopPeripheralMonitoring
{
    if (self.centralManager.state == CBCentralManagerStatePoweredOn) {
        [self.centralManager stopScan];
        self.isScanningForPeripherals = NO;
        [self debugPeripheral:nil];
    }
    if (self.connectedPeripheral) {
        [self.centralManager cancelPeripheralConnection:self.connectedPeripheral];
    }
}


- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSLog(@"%s %d", __PRETTY_FUNCTION__, (int)central.state);
    if (central.state == CBCentralManagerStatePoweredOn) {
        [self findAndConnectAirlockPeripheral];
    }
}

- (void)findAndConnectAirlockPeripheral
{
    if (self.connectedPeripheral == nil) {
        [self scanForPeripherals];
    }
}

- (void)scanForPeripherals
{
    if (self.isScanningForPeripherals) return;
    self.isScanningForPeripherals = YES;
    
    [self.delegate airlockService:self didUpdateStatus:@"discover"];
    [self.delegate airlockService:self didUpdateRSSI:0];

        // check for already connected peripherals
    /* * /
    NSArray* serviceUUIDs = @[[CBUUID UUIDWithString:kALServiceUUID]];
    NSArray* connectedPeripherals = [self.centralManager retrieveConnectedPeripheralsWithServices:serviceUUIDs];
    NSLog(@"ConnectedPeripherals %@", connectedPeripherals);
    
    if (connectedPeripherals.count > 0) {
        [self.centralManager connectPeripheral:connectedPeripherals.firstObject options:nil];
        return;
    }
    // */
    
        // check for identified peripherals
    /* * /
    NSString* peripheralIdentifier = [[NSUserDefaults standardUserDefaults] stringForKey:@"connectedPeripheralIdentifier"];
    if (peripheralIdentifier) {
        NSUUID* identifierUUID = [[NSUUID UUID] initWithUUIDString:peripheralIdentifier];
        NSArray* identifiedPeripherals = [self.centralManager retrievePeripheralsWithIdentifiers:@[identifierUUID]];
        NSLog(@"PeripheralsWithIdentifier %@ %@", peripheralIdentifier, identifiedPeripherals);
    
        if (identifiedPeripherals.count > 0) {
            [self.centralManager connectPeripheral:identifiedPeripherals.firstObject options:nil];
            return;
        }
    }
    // */

    self.peripheralsToCheck = [NSMutableArray array];
    self.discoveredPeripherals = [NSMutableDictionary dictionary];
    [self.centralManager scanForPeripheralsWithServices:nil
                                                options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @YES}];
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
//    NSLog(@"%s", __PRETTY_FUNCTION__);

    NSString *reasonToIgnore = nil;
    if ([self.peripheralsToCheck containsObject:peripheral]) {
        reasonToIgnore = @"checking";
    }
    else if (peripheral.state == CBPeripheralStateConnected) {
        reasonToIgnore = @"connected";
    }
    else if (peripheral.state == CBPeripheralStateConnecting) {
        reasonToIgnore = @"connecting";
    }
    else if ([peripheral.name isEqualToString:@"estimote"]) {
        reasonToIgnore = @"ignore estimotes";
    }
    else if ([self.ignorePeripheralIdentifiers containsObject:peripheral.identifier]) {
        reasonToIgnore = @"failed challenge";
    }
    else if ([RSSI intValue] <= self.RSSIMinimumToConnect) {
        reasonToIgnore = @"out of range";
    }
    
    NSDictionary *peripheralDebugInformations = @{
                                                  @"identifier": peripheral.identifier.UUIDString,
                                                  @"name": [NSString stringWithFormat:@"%@", peripheral.name],
                                                  @"state": [NSString stringWithFormat:@"%ld", peripheral.state],
                                                  @"RSSI": [NSString stringWithFormat:@"%d", [RSSI intValue]],
                                                  @"ignore": [NSString stringWithFormat:@"%@", reasonToIgnore]
                                                  };
    
    [self debugPeripheral:peripheralDebugInformations];
    
//    NSLog(@"     %@ %@", [peripheral.identifier UUIDString], reasonToIgnore);
    
    if (reasonToIgnore == nil) {
        peripheral.delegate = self;
        [self.peripheralsToCheck addObject:peripheral];
        if (self.lastConnectedPeripheralIdentifier && [peripheral.identifier isEqualTo:self.lastConnectedPeripheralIdentifier]) {
            NSLog(@"fast reconnect to last peripheral");
            [self connectToAirlockPeripheral:peripheral];
        }
        [self.centralManager connectPeripheral:peripheral
                                       options:@{CBConnectPeripheralOptionNotifyOnDisconnectionKey: @YES}];
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    if ([peripheral isEqualTo:self.connectedPeripheral]) {
        self.connectedPeripheral = nil;
        [self.delegate airlockService:self didUpdateStatus:@"disconnected"];
        [self.delegate airlockService:self didUpdateRSSI:0];
        self.peripheralIsNearby = NO;
        [self performSelector:@selector(performConnectedPeripheralLeavesRange) withObject:nil afterDelay:3.0f];
    }

    [self.peripheralsToCheck removeObject:peripheral];
    if (self.peripheralsToCheck.count == 0) {
        [self findAndConnectAirlockPeripheral];
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self.peripheralsToCheck removeObject:peripheral];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if ([self.peripheralsToCheck containsObject:peripheral]) {
        [peripheral discoverServices:@[[CBUUID UUIDWithString:kALServiceUUID]]];
        // TODO timeout for didDiscoverServices
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);

    if (peripheral.services.count > 0) {
        [self serviceWithUUID:[CBUUID UUIDWithString:kALServiceUUID]
                         from:peripheral
                    withBlock:^(CBService *service, CBPeripheral *peripheral) {
                        [peripheral discoverCharacteristics:@[
                                                                            [CBUUID UUIDWithString:kALCharacteristicDeviceNameUUID],
                                                                            [CBUUID UUIDWithString:kALCharacteristicReadChallengeUUID],
                                                                            [CBUUID UUIDWithString:kALCharacteristicWriteChallengeUUID]
                                                                            ]
                                                               forService:service];
                    }];
    } else {
        [self.peripheralsToCheck removeObject:peripheral];
    }
}

- (void)connectToAirlockPeripheral:(CBPeripheral*)peripheral
{
    NSLog(@"%s", __PRETTY_FUNCTION__);

    [self.centralManager stopScan];
    self.isScanningForPeripherals = NO;
    self.peripheralIsNearby = YES;
    [self debugPeripheral:nil];

    if (self.connectedPeripheral == nil || ![self.connectedPeripheral isEqualTo:peripheral]) {
        [self.delegate airlockService:self didUpdateStatus:[NSString stringWithFormat:@"connected (- %@)", [peripheral.identifier UUIDString]]];
        [self.delegate airlockService:self didUpdateRSSI:0];

        self.connectedPeripheral = peripheral;
        self.lastConnectedPeripheralIdentifier = peripheral.identifier;
        
        [self serviceWithUUID:[CBUUID UUIDWithString:kALServiceUUID]
                         from:peripheral
                    withBlock:^(CBService *service, CBPeripheral *peripheral) {
                        [self characteristicWithUUID:[CBUUID UUIDWithString:kALCharacteristicDeviceNameUUID]
                                                from:peripheral
                                             service:service
                                           withBlock:^(CBCharacteristic *characteristic, CBService *service, CBPeripheral *peripheral) {
                                               [peripheral readValueForCharacteristic:characteristic];
                                           }];
                    }];

        [self startRSSIMontitoring];
        [self performConnectedPeripheralEntersRange];
        
        NSDictionary *peripheralDebugInformations = @{
                                                      @"identifier": peripheral.identifier.UUIDString,
                                                      @"name": [NSString stringWithFormat:@"%@", peripheral.name],
                                                      @"state": [NSString stringWithFormat:@"%ld", peripheral.state],
                                                      @"RSSI": [NSString stringWithFormat:@"%d", 0],
                                                      @"ignore": [NSString stringWithFormat:@"%@", @"connected"]
                                                      };
        
        [self debugPeripheral:peripheralDebugInformations];
        
        for (CBPeripheral* connectedPeripheral in self.peripheralsToCheck) {
            if (![self.connectedPeripheral isEqualTo:connectedPeripheral]) {
                [self.centralManager cancelPeripheralConnection:connectedPeripheral];
                [self.peripheralsToCheck removeObject:connectedPeripheral];
            }
        }
    }

}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (service.characteristics.count > 0) {
        for (CBCharacteristic* c in service.characteristics) {
            NSLog(@"%@", c.UUID);
        }
        [self characteristicWithUUID:[CBUUID UUIDWithString:kALCharacteristicReadChallengeUUID]
                                from:peripheral
                             service:service
                           withBlock:^(CBCharacteristic *characteristic, CBService *service, CBPeripheral *peripheral) {
                               [peripheral readValueForCharacteristic:characteristic];
                           }];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"%s %@ %@", __PRETTY_FUNCTION__, characteristic.UUID, [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding]);
    if (error) NSLog(@"   error %@", error);
    if (!error) {
        if ([characteristic.UUID isEqualTo:[CBUUID UUIDWithString:kALCharacteristicDeviceNameUUID]]) {
            NSString *deviceName = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
            [self.delegate airlockService:self didUpdateStatus:[NSString stringWithFormat:@"connected (%@ %@)", deviceName, [peripheral.identifier UUIDString]]];
        }
        
        if ([characteristic.UUID isEqualTo:[CBUUID UUIDWithString:kALCharacteristicReadChallengeUUID]]) {
            NSString *incomingChallenge = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
            [self handleIncomingChallenge:incomingChallenge peripheral:peripheral service:characteristic.service];
        }

        if ([characteristic.UUID isEqualTo:[CBUUID UUIDWithString:kALCharacteristicWriteChallengeUUID]]) {
            NSString *response = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];

            if (self.responseValueBuffer == nil) self.responseValueBuffer = @"";
            
            self.responseValueBuffer = [self.responseValueBuffer stringByAppendingString:response];
            if ([[self.responseValueBuffer substringFromIndex:(self.responseValueBuffer.length - 1)] isEqualToString:@"#"]) {
                [self checkClientResponse:self.responseValueBuffer peripheral:peripheral];
                self.responseValueBuffer = nil;
            }
        }
    }
}

- (void)handleIncomingChallenge:(NSString*)incomingChallenge peripheral:(CBPeripheral *)peripheral service:(CBService*)service
{
    self.incomingChallenge = incomingChallenge;
    self.outgoingChallenge = [self sha1:[self generateRandomString:40]];
    NSLog(@"outgoingChallenge %@", self.outgoingChallenge);

    [self characteristicWithUUID:[CBUUID UUIDWithString:kALCharacteristicWriteChallengeUUID]
                            from:peripheral
                         service:service
                       withBlock:^(CBCharacteristic *characteristic, CBService *service, CBPeripheral *peripheral) {
                           [peripheral setNotifyValue:YES forCharacteristic:characteristic];
                       }];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (error) NSLog(@"   error %@", error);
    
    if ([characteristic.UUID isEqualTo:[CBUUID UUIDWithString:kALCharacteristicWriteChallengeUUID]]) {
        NSString *response = [NSString stringWithFormat:@"%@.%@",
                              [self sha1:[NSString stringWithFormat:@"%@%@%@", self.incomingChallenge, self.outgoingChallenge, kALChallengeSecret]],
                              self.outgoingChallenge];
        [peripheral writeValue:[response dataUsingEncoding:NSUTF8StringEncoding]
             forCharacteristic:characteristic
                          type:CBCharacteristicWriteWithResponse];
    }
}

- (void)checkClientResponse:(NSString*)response peripheral:(CBPeripheral *)peripheral
{
    response = [response substringToIndex:(response.length - 1)];
    
    if ([response isEqualToString:@"error"]) {
        NSLog(@"clientResponse error");
        [self.ignorePeripheralIdentifiers addObject:peripheral.identifier];
        [self.peripheralsToCheck removeObject:peripheral];
        [self.centralManager cancelPeripheralConnection:peripheral];
        return;
    }

    NSArray *chunks = [response componentsSeparatedByString:@"."];
    NSString *challengeResponse = chunks.firstObject;
    NSString *newChallenge = chunks.lastObject;

    NSString *expectedChallengeResponse = [self sha1:[NSString stringWithFormat:@"%@%@%@", self.outgoingChallenge, newChallenge, kALChallengeSecret]];
    
    if ([challengeResponse isEqualToString:expectedChallengeResponse]) {
        NSLog(@"challenge accepted!");
        [self connectToAirlockPeripheral:peripheral];
    } else {
        NSLog(@"invalid challenge!");
        [self.ignorePeripheralIdentifiers addObject:peripheral.identifier];
        [self.peripheralsToCheck removeObject:peripheral];
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (error) NSLog(@"   error %@", error);
}

-(NSString*)generateRandomString:(int)num {
    NSMutableString* string = [NSMutableString stringWithCapacity:num];
    for (int i = 0; i < num; i++) {
        [string appendFormat:@"%C", (unichar)('a' + arc4random_uniform(25))];
    }
    return string;
}

#pragma mark -

- (NSString *)sha1:(NSString*)string
{
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    
    CC_SHA1(data.bytes, (unsigned int)data.length, digest);
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    
    return output;
}

- (void)startRSSIMontitoring
{
    self.rssiUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                            target:self
                                                          selector:@selector(updateRssiValue:)
                                                          userInfo:nil
                                                           repeats:YES];
    self.rssiUpdateTimer.tolerance = 1.0;
}

- (void)stopRSSIMonitoring
{
    [self.rssiUpdateTimer invalidate];
    self.rssiUpdateTimer = nil;
}

- (void)updateRssiValue:(NSTimer*)timer
{
    if (self.connectedPeripheral
        && (self.connectedPeripheral.state == CBPeripheralStateConnecting || self.connectedPeripheral.state == CBPeripheralStateConnected)) {
            [self.connectedPeripheral readRSSI];
        } else {
            [self stopRSSIMonitoring];
        }
}

- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error
{
    [self.delegate airlockService:self didUpdateRSSI:[peripheral.RSSI intValue]];
    
    if ([peripheral.RSSI intValue] <= self.RSSIMinimumToDisconnect) {
        [self.delegate airlockService:self didUpdateStatus:@"peripheral out of range"];
        
        [self stopRSSIMonitoring];

        [self.centralManager cancelPeripheralConnection:peripheral];
        [self.peripheralsToCheck removeObject:peripheral];
        if (self.peripheralsToCheck.count == 0) {
            [self findAndConnectAirlockPeripheral];
        }
    }
}

- (void)serviceWithUUID:(CBUUID*)uuid
                   from:(CBPeripheral*)peripheral
              withBlock:(void (^)(CBService* service, CBPeripheral* peripheral))executeBlock
{
    CBService* desiredService = nil;
    for (CBService* service in peripheral.services) {
        if ([service.UUID isEqual:uuid]) {
            desiredService = service;
            break;
        }
    }
    if (desiredService != nil) {
        if (executeBlock) executeBlock(desiredService, peripheral);
    }
}

- (void)characteristicWithUUID:(CBUUID*)uuid
                          from:(CBPeripheral*)peripheral
                       service:(CBService*)service
                     withBlock:(void (^)(CBCharacteristic* characteristic, CBService* service, CBPeripheral* peripheral))executeBlock
{
    CBCharacteristic* desiredCharacteristic = nil;
    for (CBCharacteristic* characteristic in service.characteristics) {
        if ([characteristic.UUID isEqual:uuid]) {
            desiredCharacteristic = characteristic;
            break;
        }
    }
    if (desiredCharacteristic != nil) {
        if (executeBlock) executeBlock(desiredCharacteristic, service, peripheral);
    }
}

#pragma mark -

- (void)debugPeripheral:(NSDictionary*)peripheralDebugInformations
{
    if (peripheralDebugInformations == nil && self.connectedPeripheral) {
        peripheralDebugInformations = @{
                                                      @"identifier": self.connectedPeripheral.identifier.UUIDString,
                                                      @"name": [NSString stringWithFormat:@"%@", self.connectedPeripheral.name],
                                                      @"state": [NSString stringWithFormat:@"%ld", self.connectedPeripheral.state],
                                                      @"RSSI": [NSString stringWithFormat:@"%d", [self.connectedPeripheral.RSSI intValue]],
                                                      @"ignore": @"-"
                                                      };
    }
    if (peripheralDebugInformations) {
        [self.discoveredPeripherals setValue:peripheralDebugInformations forKey:[peripheralDebugInformations valueForKey:@"identifier"]];
    }

    NSString *output = [@"" mutableCopy];
    
    output = [output stringByAppendingFormat:@"scaning: %@", self.isScanningForPeripherals ? @"YES" : @"NO"];
    output = [output stringByAppendingFormat:@"   |   peripheral is nearby: %@", self.peripheralIsNearby ? @"YES" : @"NO"];

    for (NSDictionary* peripheral in [self.discoveredPeripherals.allValues sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"identifier"
                                                                                                                                       ascending:YES]]]) {
        output = [output stringByAppendingFormat:@"\n%@ %@ %@ %@ %@",
                  [peripheral valueForKey:@"identifier"],
                  [peripheral valueForKey:@"name"],
                  [peripheral valueForKey:@"state"],
                  [peripheral valueForKey:@"RSSI"],
                  [peripheral valueForKey:@"ignore"]
                  ];
    }
    
    ALAppDelegate *applicationDelegate = (ALAppDelegate*)[NSApplication sharedApplication].delegate;
    [applicationDelegate setDebug:output];
    
}

@end
