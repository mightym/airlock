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
#import "NSData+AESAdditions.h"

#define kALServiceUUID @"0A84"
#define kALCharacteristicCryptedInterfaceUUID @"364F"
#define kALChallengeSecret @"FBC29689-D890-4DCD-A7D2-41A95CAFBB5D"

@interface ALDebugOverviewTableViewController () <CBPeripheralManagerDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) IBOutlet UISwitch* switchAdvertisePeripheral;
@property (strong, nonatomic) CBPeripheralManager *peripheralManager;
@property (strong, nonatomic) CBMutableCharacteristic *cryptedInterfaceCharacteristic;
@property (strong, nonatomic) CBMutableService *service;

@property (nonatomic) NSTimer* rssiUpdateTimer;
@property (nonatomic) CLProximity lastBeaconProximity;

@property (nonatomic) NSMutableData* queuedData;

@property (nonatomic, copy) void (^alertAcceptCallback)();
@property (nonatomic, copy) void (^alertCancelCallback)();

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
    self.cryptedInterfaceCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:kALCharacteristicCryptedInterfaceUUID]
                                                                           properties:CBCharacteristicPropertyWrite | CBCharacteristicPropertyNotify
                                                                                value:nil
                                                                          permissions:CBAttributePermissionsWriteable];

    
    CBMutableService* service = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:kALServiceUUID]
                                                               primary:YES];
    service.characteristics = @[
                                self.cryptedInterfaceCharacteristic
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
    
    if ([firstRequest.characteristic.UUID isEqual:[CBUUID UUIDWithString:kALCharacteristicCryptedInterfaceUUID]]) {
        NSMutableData *incomingData = [[NSMutableData alloc] init];
        for (CBATTRequest* request in requests) {
            [incomingData appendData:request.value];
        }
        NSString *salt = [[NSString alloc] initWithData:[incomingData subdataWithRange:NSMakeRange([incomingData length] - 32, 32)] encoding:NSUTF8StringEncoding];
        NSData *cryptedData = [incomingData subdataWithRange:NSMakeRange(0, [incomingData length] - 32)];
        
        NSString *request = [[NSString alloc] initWithData:[cryptedData AES256DecryptWithKey:@"4C2C93388CC841BB9BB69811CC0483E9" iv:salt] encoding:NSUTF8StringEncoding];

        NSArray *requestParts = [request componentsSeparatedByString:@"@"];
        NSString *command = requestParts.firstObject;
        NSArray *arguments = [((NSString*)requestParts.lastObject) componentsSeparatedByString:@","];
        
        NSLog(@"command %@", command);
        
        if ([command isEqualToString:@"requestPairing"]) {
            
            __block ALDebugOverviewTableViewController* blockSelf = self;
            self.alertAcceptCallback = ^void() {
                [blockSelf sendCryptedResponse:@"okay" peripheral:peripheral];
                [peripheral respondToRequest:firstRequest withResult:CBATTErrorSuccess];
            };
            self.alertCancelCallback = ^void() {
                [blockSelf sendCryptedResponse:@"canceled" peripheral:peripheral];
                [peripheral respondToRequest:firstRequest withResult:CBATTErrorWriteNotPermitted];
            };
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Accept pairing"
                                                                message:[NSString stringWithFormat:@"Allow Airlock to pair with \"%@\"?", arguments.firstObject]
                                                               delegate:self
                                                      cancelButtonTitle:@"cancel"
                                                      otherButtonTitles:@"accept", nil];
            [alertView show];
            return;

        } else if ([command isEqualToString:@"deviceName"]) {
            NSString *deviceName = [[UIDevice currentDevice] name];
            [self sendCryptedResponse:deviceName peripheral:peripheral];
            return;

        } else if ([command isEqualToString:@"devicePlatform"]) {
            struct utsname systemInfo;
            uname(&systemInfo);
            NSString* platform = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
            [self sendCryptedResponse:platform peripheral:peripheral];
            return;
        }

    } else {
        [peripheral respondToRequest:firstRequest withResult:CBATTErrorAttributeNotFound];
    }
}

- (void)sendCryptedResponse:(NSString*)response peripheral:(CBPeripheralManager *)peripheral
{
    NSString* salt = [self generateRandomString:32];
    NSData* cryptedResponse = [[response dataUsingEncoding:NSUTF8StringEncoding] AES256EncryptWithKey:@"4C2C93388CC841BB9BB69811CC0483E9" iv:salt];
    NSMutableData* cryptedResponseWithSalt = [cryptedResponse mutableCopy];
    [cryptedResponseWithSalt appendData:[[NSString stringWithFormat:@"%@", salt] dataUsingEncoding:NSUTF8StringEncoding]];

    self.queuedData = cryptedResponseWithSalt;
    [self.queuedData appendData:[@"#EOM#" dataUsingEncoding:NSUTF8StringEncoding]];

    [self sendQueuedData:peripheral forCharacteristic:self.cryptedInterfaceCharacteristic];
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    [self sendQueuedData:peripheral forCharacteristic:self.cryptedInterfaceCharacteristic];
}

- (void)sendQueuedData:(CBPeripheralManager *)peripheral forCharacteristic:(CBMutableCharacteristic*)characteristic
{
    BOOL success = YES;
    while (success && self.queuedData.length > 0) {
        int chunkSize = 20;
        NSData *chunk = [self.queuedData subdataWithRange:NSMakeRange(0, MIN(chunkSize, self.queuedData.length))];
        success = [peripheral updateValue:chunk
                        forCharacteristic:characteristic
                     onSubscribedCentrals:nil];
        if (success) {
            self.queuedData = [[self.queuedData subdataWithRange:NSMakeRange(chunk.length, self.queuedData.length - chunk.length)] mutableCopy];
        }
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"%s %@", __PRETTY_FUNCTION__, central);
}

#pragma mark -

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0) {
        if (self.alertCancelCallback) {
            self.alertCancelCallback();
            self.alertCancelCallback = nil;
        }
    }
    if (buttonIndex == 1) {
        if (self.alertAcceptCallback) {
            self.alertAcceptCallback();
            self.alertAcceptCallback = nil;
        }
    }
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
