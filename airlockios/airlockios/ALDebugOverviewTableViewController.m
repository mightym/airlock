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

#define kALServiceUUID @"0A84"
#define kALCharacteristic0UUID @"5CFE"
#define kALCharacteristic1UUID @"482D"
#define kALCharacteristic2UUID @"F966"
#define kALCharacteristic3UUID @"F310"

@interface ALDebugOverviewTableViewController () <CBPeripheralManagerDelegate>

@property (nonatomic, strong) IBOutlet UISwitch* switchAdvertisePeripheral;
@property (strong, nonatomic) CBPeripheralManager *peripheralManager;
@property (strong, nonatomic) CBMutableCharacteristic *characteristic;
@property (strong, nonatomic) CBMutableService *service;

@property (nonatomic) NSTimer* rssiUpdateTimer;
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
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
}

- (void)stopAdvertiseAsPeripheral
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if ([self.peripheralManager isAdvertising]) [self.peripheralManager stopAdvertising];
}


- (void)enablePeripheralService
{
    
    CBMutableCharacteristic* deviceNamecharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:kALCharacteristic0UUID]
                                                                                 properties:CBCharacteristicPropertyRead
                                                                                      value:[[[UIDevice currentDevice] name] dataUsingEncoding:NSUTF8StringEncoding]
                                                                                permissions:CBAttributePermissionsReadable];
    
    CBMutableCharacteristic* characteristic1 = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:kALCharacteristic1UUID]
                                                                                  properties:CBCharacteristicPropertyRead
                                                                                       value:nil
                                                                                 permissions:CBAttributePermissionsReadable];
    
    CBMutableCharacteristic* characteristic2 = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:kALCharacteristic2UUID]
                                                                                  properties:CBCharacteristicPropertyWrite
                                                                                       value:nil
                                                                                 permissions:CBAttributePermissionsWriteable];
    
    CBMutableCharacteristic* characteristic3 = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:kALCharacteristic3UUID]
                                                                                  properties:CBCharacteristicPropertyWrite
                                                                                       value:nil
                                                                                 permissions:CBAttributePermissionsWriteEncryptionRequired];
    
    
    CBMutableService* service = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:kALServiceUUID]
                                                               primary:YES];
    service.characteristics = @[deviceNamecharacteristic /*, characteristic1, characteristic2, characteristic3*/];
    
    self.service = service;
    
    if (self.peripheralManager.isAdvertising) [self.peripheralManager stopAdvertising];
    [self.peripheralManager removeAllServices];
    [self.peripheralManager addService:self.service];
}

- (void)startAdvertisingPeripheral {
    [self.peripheralManager startAdvertising:@{
//                                               CBAdvertisementDataLocalNameKey: @"airlockIOS",
//                                               CBAdvertisementDataServiceUUIDsKey: @[[CBUUID UUIDWithString:kALServiceUUID]]
                                               }];
}

#pragma mark - CBPeripheralManagerDelegate

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    NSLog(@"%s %ld", __PRETTY_FUNCTION__, peripheral.state);
    if (peripheral.state == CBPeripheralManagerStatePoweredOn) {
        if (peripheral == self.peripheralManager) {
            [self enablePeripheralService];
        }
    }
    // TODO check the other states
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self startAdvertisingPeripheral];
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (error) NSLog(@"%@", error);
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"  %@", request.central.identifier);
    
    
    if ([request.characteristic.UUID isEqual:[CBUUID UUIDWithString:@"482D14E2-DA9A-4795-9841-9DF3F8165259"]]) {
        
        NSData *value = [[[NSDate date] description] dataUsingEncoding:NSUTF8StringEncoding];
        if (request.offset > value.length) {
            [peripheral respondToRequest:request withResult:CBATTErrorInvalidOffset];
            return;
        }
        
        request.value = [value subdataWithRange:NSMakeRange(request.offset, MIN(value.length - request.offset, 20))];
        [peripheral respondToRequest:request withResult:CBATTErrorSuccess];
//    [peripheral respondToRequest:request withResult:CBATTErrorInsufficientAuthentication];
        return;
    }
    
    [peripheral respondToRequest:request withResult:CBATTErrorRequestNotSupported];
    
    return;
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests
{
    for (CBATTRequest* request in requests) {
        NSLog(@"request.value: %@ (for %@)",
              [[NSString alloc] initWithData:request.value encoding:NSUTF8StringEncoding],
              request.characteristic.UUID);
        [peripheral respondToRequest:request withResult:CBATTErrorSuccess];
    }
}

#pragma mark -

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
