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
#import <CommonCrypto/CommonDigest.h>
#include <sys/utsname.h>

#define kALServiceUUID @"0A84"
#define kALCharacteristicDeviceNameUUID @"5CFE"
#define kALCharacteristicDevicePlatformUUID @"1319"
#define kALCharacteristicWriteChallengeUUID @"482D"
#define kALCharacteristicReadChallengeUUID @"F966"
#define kALChallengeSecret @"FBC29689-D890-4DCD-A7D2-41A95CAFBB5D"

@interface ALDebugOverviewTableViewController () <CBPeripheralManagerDelegate>

@property (nonatomic, strong) IBOutlet UISwitch* switchAdvertisePeripheral;
@property (strong, nonatomic) CBPeripheralManager *peripheralManager;
@property (strong, nonatomic) CBMutableCharacteristic *deviceNameCharacteristic;
@property (strong, nonatomic) CBMutableCharacteristic *devicePlatformCharacteristic;
@property (strong, nonatomic) CBMutableCharacteristic *readChallengeCharacteristic;
@property (strong, nonatomic) CBMutableCharacteristic *writeChallengeCharacteristic;
@property (strong, nonatomic) CBMutableService *service;

@property (nonatomic) NSTimer* rssiUpdateTimer;
@property (nonatomic) CLProximity lastBeaconProximity;

@property (nonatomic) NSString* queuedData;
@property (nonatomic) NSString* readChallengeValue;

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

- (IBAction)switchAdvertisePeripheral:(id)sender
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (self.switchAdvertisePeripheral.on) {
        [self startAdvertiseAsPeripheral];
    } else {
        [self stopAdvertiseAsPeripheral];
    }
}

#pragma mark - BlueTooth LE

- (void)startAdvertiseAsPeripheral
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self stopAdvertiseAsPeripheral];
    if (self.peripheralManager == nil) {
        self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
    } else {
        [self peripheralManagerDidUpdateState:self.peripheralManager];
    }
}

- (void)stopAdvertiseAsPeripheral
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if ([self.peripheralManager isAdvertising]) [self.peripheralManager stopAdvertising];
}


- (void)enablePeripheralService
{
    
    self.deviceNameCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:kALCharacteristicDeviceNameUUID]
                                                                                 properties:CBCharacteristicPropertyRead
                                                                                      value:[[[UIDevice currentDevice] name] dataUsingEncoding:NSUTF8StringEncoding]
                                                                                permissions:CBAttributePermissionsReadable];

    struct utsname systemInfo;
    uname(&systemInfo);
    NSString* platform = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    
    self.devicePlatformCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:kALCharacteristicDevicePlatformUUID]
                                                                       properties:CBCharacteristicPropertyRead
                                                                            value:[platform dataUsingEncoding:NSUTF8StringEncoding]
                                                                      permissions:CBAttributePermissionsReadable];

    self.readChallengeValue = [self sha1:[self generateRandomString:40]];
    self.readChallengeCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:kALCharacteristicReadChallengeUUID]
                                                                          properties:CBCharacteristicPropertyRead
                                                                               value:[self.readChallengeValue dataUsingEncoding:NSUTF8StringEncoding]
                                                                         permissions:CBAttributePermissionsReadable];
    
    self.writeChallengeCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:kALCharacteristicWriteChallengeUUID]
                                                                                  properties:CBCharacteristicPropertyWrite | CBCharacteristicPropertyNotify
                                                                                       value:nil
                                                                                 permissions:CBAttributePermissionsWriteable];
    
    
    CBMutableService* service = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:kALServiceUUID]
                                                               primary:YES];
    service.characteristics = @[
                                self.deviceNameCharacteristic,
                                self.devicePlatformCharacteristic,
                                self.readChallengeCharacteristic,
                                self.writeChallengeCharacteristic
                                ];
    
    self.service = service;
    
    if (self.peripheralManager.isAdvertising) {
        [self.peripheralManager stopAdvertising];
    }
    [self.peripheralManager removeAllServices];
    [self.peripheralManager addService:self.service];
}

- (void)startAdvertisingPeripheral {
    [self.peripheralManager startAdvertising:@{}];
}

#pragma mark - CBPeripheralManagerDelegate

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    NSLog(@"%s %ld", __PRETTY_FUNCTION__, peripheral.state);

    switch (peripheral.state) {
        case CBPeripheralManagerStatePoweredOn:
            if (peripheral == self.peripheralManager) {
                [self enablePeripheralService];
            }
            break;

        case CBPeripheralManagerStateUnsupported:
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Bluetooth"
                                                            message:@"Your device is not supported."
                                                           delegate:self
                                                  cancelButtonTitle:@"Okay"
                                                  otherButtonTitles:nil];
            [alert show];
            self.switchAdvertisePeripheral.on = NO;
            break;
        }
            
        default:
            self.switchAdvertisePeripheral.on = NO;
            break;
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error {
    [self startAdvertisingPeripheral];
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error
{
    if (error) NSLog(@"%@", error);
}


- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests
{
    CBATTRequest* firstRequest = requests.firstObject;
    if ([firstRequest.characteristic.UUID isEqual:[CBUUID UUIDWithString:kALCharacteristicWriteChallengeUUID]]) {
        NSString *incomingString = @"";
        for (CBATTRequest* request in requests) {
            incomingString = [incomingString stringByAppendingString:[[NSString alloc] initWithData:request.value encoding:NSUTF8StringEncoding]];
        }
        
        if ([incomingString isEqualToString:@""]) {
            [peripheral respondToRequest:firstRequest withResult:CBATTErrorRequestNotSupported];
            return;
        }
        
        NSLog(@"incomingChallenge %@", incomingString);
        
        NSArray *chunks = [incomingString componentsSeparatedByString:@"."];
        NSString *challengeResponse = chunks.firstObject;
        NSString *incomingChallenge = chunks.lastObject;
        
        NSString *expectedChallengeResponse = [self sha1:[NSString stringWithFormat:@"%@%@%@", self.readChallengeValue, incomingChallenge, kALChallengeSecret]];
        
        if ([challengeResponse isEqualToString:expectedChallengeResponse]) {
            NSLog(@"challenge accepted!");
            NSString *newChallenge = [self sha1:[self generateRandomString:40]];
            NSString *challengeResponse = [self sha1:[NSString stringWithFormat:@"%@%@%@", incomingChallenge, newChallenge, kALChallengeSecret]];

            NSLog(@"newChallenge %@", newChallenge);
            NSString *response = [NSString stringWithFormat:@"%@.%@", challengeResponse, newChallenge];
            NSLog(@"response %@", response);
            
            [self sendChallengeResponse:response peripheral:peripheral];
            [peripheral respondToRequest:firstRequest withResult:CBATTErrorSuccess];
        } else {
            NSLog(@"invalid challenge!");
            [self sendChallengeResponse:@"error" peripheral:peripheral];
            [peripheral respondToRequest:firstRequest withResult:CBATTErrorWriteNotPermitted];
        }
    } else {
        [peripheral respondToRequest:firstRequest withResult:CBATTErrorAttributeNotFound];
    }
}

- (void)sendChallengeResponse:(NSString*)response peripheral:(CBPeripheralManager *)peripheral
{
    self.queuedData = [NSString stringWithFormat:@"%@#", response];
    [self sendQueuedData:peripheral];
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    [self sendQueuedData:peripheral];
}

- (void)sendQueuedData:(CBPeripheralManager *)peripheral
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    BOOL success = YES;
    while (success && self.queuedData.length > 0) {
        int chunkSize = 20;
        NSString *chunk = [self.queuedData substringWithRange:NSMakeRange(0, MIN(chunkSize, self.queuedData.length))];
        NSLog(@"send %@", chunk);
        success = [peripheral updateValue:[chunk dataUsingEncoding:NSUTF8StringEncoding]
                        forCharacteristic:self.writeChallengeCharacteristic
                     onSubscribedCentrals:nil];
        if (success) {
            self.queuedData = [self.queuedData substringFromIndex:chunk.length];
        }
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"%s %@", __PRETTY_FUNCTION__, central);
}

#pragma mark -

-(NSString*)generateRandomString:(int)num
{
    NSMutableString* string = [NSMutableString stringWithCapacity:num];
    for (int i = 0; i < num; i++) {
        [string appendFormat:@"%C", (unichar)('a' + arc4random_uniform(25))];
    }
    return string;
}

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

#pragma mark -

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
