//
//  ALBluetoothScanner.m
//  airlockmac
//
//  Created by Tobias Liebig on 18.12.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALBluetoothScanner.h"
#import "ALDiscoveredDevice.h"

#import "NSMutableArray+fifoQueue.h"


NSString *const kALNotificationsBluetoothServiceDidFoundNewDeviceNotification = @"kALNotificationsBluetoothServiceDidFoundNewDeviceNotification";
NSString *const kALNotificationsBluetoothServiceDeviceDisappearedNotification = @"kALNotificationsBluetoothServiceDeviceDisappearedNotification";
NSString *const kALNotificationsBluetoothServiceDeviceUpdatedNotification = @"kALNotificationsBluetoothServiceDeviceUpdatedNotification";

#define kALServiceUUID @"0a84"
#define kALCharacteristicCryptedInterfaceUUID @"364f"
#define kALChallengeSecret @"FBC29689-D890-4DCD-A7D2-41A95CAFBB5D"


@interface ALBluetoothScanner ()

@property BOOL isScanningForPeripherals;

@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) NSTimer *checkDisappearedDevicesTimer;

@property (strong, nonatomic) CBUUID *serviceUUID;
@property (strong, nonatomic) CBUUID *characteristicCryptedInterfaceUUID;

@property (strong, nonatomic) NSMutableArray *peripheralIdentifierToIgnore;
@property (strong, nonatomic) NSMutableArray *currentPeripherals;

@property (strong, nonatomic) NSMutableArray *readCallbackStack;
@property (strong, nonatomic) NSMutableArray *writeCallbackStack;

@property (nonatomic, strong) NSMutableData* responseValueBuffer;

@end

@implementation ALBluetoothScanner

#pragma mark - life cycle

+ (instancetype)sharedService
{
    static ALBluetoothScanner *_sharedService = nil;
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
        self.isScanningForPeripherals = NO;
        self.serviceUUID = [CBUUID UUIDWithString:kALServiceUUID];
        self.characteristicCryptedInterfaceUUID = [CBUUID UUIDWithString:kALCharacteristicCryptedInterfaceUUID];
        self.peripheralIdentifierToIgnore = [NSMutableArray array];
        self.currentPeripherals = [NSMutableArray array];
        
        self.readCallbackStack = [NSMutableArray array];
        self.writeCallbackStack = [NSMutableArray array];
    }
    return self;
}

#pragma mark - public API

-(void)startScanning
{
    if (self.isScanningForPeripherals) return;
    self.isScanningForPeripherals = YES;
    
    if (self.centralManager == nil) {
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                                   queue:dispatch_queue_create("com.wirblich.airlock.cb", NULL)
                                                                 options:nil];
    } else {
        [self centralManagerDidUpdateState:self.centralManager];
    }
}


-(void)stopScanning
{
    if (!self.isScanningForPeripherals) return;
    self.isScanningForPeripherals = NO;
    
    if (self.centralManager) {
        [self.centralManager stopScan];
    }
    if (self.checkDisappearedDevicesTimer != nil) {
        [self.checkDisappearedDevicesTimer invalidate];
        self.checkDisappearedDevicesTimer = nil;
    }
}


- (void)write:(ALAirlockCharacteristic)characteristicToWrite
           to:(CBPeripheral*)peripheral
        value:(NSData*)value
responseCallback:(void(^)(NSData *response))responseCallback
{
    NSLog(@"%s %@", __PRETTY_FUNCTION__, [[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding]);
    if (peripheral.state == CBPeripheralStateConnected) {
        CBUUID* characteristicUuid = nil;
        
        if (characteristicToWrite == ALAirlockCharacteristicCryptedInterfaceCharacteristic) {
            characteristicUuid = self.characteristicCryptedInterfaceUUID;
        }
        
        if (characteristicUuid == nil) return;
        [self serviceWithUUID:self.serviceUUID
                         from:peripheral
                    withBlock:^(CBService *service, CBPeripheral *peripheral) {
                        [self characteristicWithUUID:characteristicUuid
                                                from:peripheral
                                             service:service
                                           withBlock:^(CBCharacteristic *characteristic, CBService *service, CBPeripheral *peripheral) {
                                               [self.writeCallbackStack push:@{
                                                                               @"responseCallback": responseCallback,
                                                                               @"value": value,
                                                                               @"characteristic": characteristic,
                                                                               @"service": service,
                                                                               @"peripheral": peripheral
                                                                               }];
                                               peripheral.delegate = self;
                                               [peripheral setNotifyValue:YES forCharacteristic:characteristic];
                                           } missingBlock:^(CBService *service, CBPeripheral *peripheral) {
                                               NSLog(@"Cant write characteristic %d", characteristicToWrite);
                                           }];
                    } missingBlock:^(CBPeripheral *peripheral) {
                        NSLog(@"Cant use service %@", self.serviceUUID);
                    }];
    } else {
        NSLog(@"not connected anymore"); // TODO reconnect?
    }
}

#pragma mark - CBCentralManagerDelegate


- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state) {
        case CBCentralManagerStatePoweredOn:
            [self discoverPeripherals];
            break;
            
        default:
            break;
    }
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
    
    if ([self.peripheralIdentifierToIgnore containsObject:peripheral.identifier])
        return;
    
    // TODO ignore device?
    
    ALDiscoveredDevice *discoveredDevice;
    discoveredDevice = [self.discovered objectForKey:peripheral.identifier];

    if (discoveredDevice == nil) {
        discoveredDevice = [[ALDiscoveredDevice alloc] init];
        discoveredDevice.identifier = peripheral.identifier;
        discoveredDevice.peripheral = peripheral;
        discoveredDevice.lastRSSI = RSSI;
        discoveredDevice.lastSeen = [NSDate date];
        discoveredDevice.deviceName = @"";
        discoveredDevice.platform = @"";
        
        [self.discovered setObject:discoveredDevice forKey:peripheral.identifier];
        
        [self.centralManager connectPeripheral:peripheral
                                       options:@{CBConnectPeripheralOptionNotifyOnDisconnectionKey: @YES}];
    } else {
        discoveredDevice.lastRSSI = RSSI;
        discoveredDevice.lastSeen = [NSDate date];
    }
}


- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self deviceDisappeared:peripheral.identifier];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self deviceDisappeared:peripheral.identifier];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (peripheral.services.count > 0) {
        [self serviceWithUUID:self.serviceUUID
                         from:peripheral
                    withBlock:^(CBService *service, CBPeripheral *peripheral) {
                        [peripheral discoverCharacteristics:nil
                                                 forService:service];
                    }
                 missingBlock:^(CBPeripheral *peripheral) {
                     [self ignorePeripheral:peripheral];
                 }];
    } else {
        NSLog(@"no services");
        [self ignorePeripheral:peripheral];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (service.characteristics.count > 0) {
        ALDiscoveredDevice *discoveredDevice;
        discoveredDevice = [self.discovered objectForKey:peripheral.identifier];
        [self postNewDeviceNotification:discoveredDevice];
    } else {
        // [self ignorePeripheral:peripheral];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"%s %@ %@", __PRETTY_FUNCTION__, characteristic.UUID, [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding]);
    if (error) {
        NSLog(@"   error %@", error);
        [self.centralManager cancelPeripheralConnection:peripheral];
        [self.discovered removeObjectForKey:peripheral.identifier];
    }
    if (!error) {
        
        if ([characteristic.UUID isEqualTo:self.characteristicCryptedInterfaceUUID]) {
            NSData *response = characteristic.value;
            if (self.responseValueBuffer == nil) self.responseValueBuffer = [NSMutableData data];
            
            [self.responseValueBuffer appendData:response];
            NSData *stopSequence = [self.responseValueBuffer subdataWithRange:NSMakeRange(self.responseValueBuffer.length - 5, 5)];
            if ([[[NSString alloc] initWithData:stopSequence encoding:NSUTF8StringEncoding] isEqualToString:@"#EOM#"]) {
                NSDictionary* writeRequest = (NSDictionary*)[self.writeCallbackStack pop];
                void (^callback)(NSData*) = [writeRequest objectForKey:@"responseCallback"];
                if (callback) callback([self.responseValueBuffer subdataWithRange:NSMakeRange(0, self.responseValueBuffer.length - 5)]);
                self.responseValueBuffer = nil;
            }

        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"%s %@ %@", __PRETTY_FUNCTION__, characteristic.UUID, [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding]);
    if (error) {
        NSLog(@"   error %@", error);
        [self.centralManager cancelPeripheralConnection:peripheral];
        [self.discovered removeObjectForKey:peripheral.identifier];
    }
    if (!error) {
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"%s %@", __PRETTY_FUNCTION__, characteristic.UUID);
    if (!error) {
        NSLog(@"b");
        if ([characteristic.UUID isEqualTo:self.characteristicCryptedInterfaceUUID]) {
                    NSLog(@"c");
            NSDictionary* writeRequest = (NSDictionary*)self.writeCallbackStack.firstObject;
            NSLog(@"%@", writeRequest);
            [peripheral writeValue:[writeRequest objectForKey:@"value"]
                 forCharacteristic:characteristic
                              type:CBCharacteristicWriteWithResponse];
        }
    } else {
        NSLog(@"error %@", error);
        [self.centralManager cancelPeripheralConnection:peripheral];
        [self.discovered removeObjectForKey:peripheral.identifier];
    }
}


#pragma mark -

- (void)postNewDeviceNotification:(ALDiscoveredDevice*)discoveredDevice
{
    dispatch_sync(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kALNotificationsBluetoothServiceDidFoundNewDeviceNotification
                                                            object:self
                                                          userInfo:@{@"newDevice": discoveredDevice}];
    });
}

- (void)postUpdateDeviceNotification:(ALDiscoveredDevice*)discoveredDevice
{
    dispatch_sync(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kALNotificationsBluetoothServiceDeviceUpdatedNotification
                                                            object:self
                                                          userInfo:@{@"updatedDevice": discoveredDevice}];
    });
}


- (void)postDeviceDisappearedNotification:(NSUUID*)identifier
{
    dispatch_sync(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kALNotificationsBluetoothServiceDeviceDisappearedNotification
                                                            object:self
                                                          userInfo:@{@"identifier": identifier}];
    });
}


- (void)discoverPeripherals
{
    self.discovered = [NSMutableDictionary dictionary];
    [self.centralManager scanForPeripheralsWithServices:nil
                                                options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @YES}];
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        self.checkDisappearedDevicesTimer = [NSTimer scheduledTimerWithTimeInterval:2
                                                                             target:self
                                                                           selector:@selector(checkDisappearedDevicesTimerFired:)
                                                                           userInfo:nil
                                                                            repeats:YES];
        self.checkDisappearedDevicesTimer.tolerance = 1.0;
    });
}

- (void)ignorePeripheral:(CBPeripheral*)peripheral
{
    NSLog(@"ignore %@", peripheral);
    if (peripheral.state == CBPeripheralStateConnected || peripheral.state == CBPeripheralStateConnecting) {
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
//    [self.peripheralIdentifierToIgnore addObject:peripheral.identifier];
    [self deviceDisappeared:peripheral.identifier];
}

- (void)deviceDisappeared:(NSUUID*)identifier
{
    [self.discovered removeObjectForKey:identifier];
    [self postDeviceDisappearedNotification:identifier];
}

- (void)checkDisappearedDevicesTimerFired:(NSTimer*)timer
{
    for (ALDiscoveredDevice* device in [self.discovered allValues]) {
        if ([device.lastSeen timeIntervalSinceNow] < -3.0) {
            [self deviceDisappeared:device.identifier];
        }
    }
}


- (void)serviceWithUUID:(CBUUID*)uuid
                   from:(CBPeripheral*)peripheral
              withBlock:(void (^)(CBService* service, CBPeripheral* peripheral))executeBlock
           missingBlock:(void (^)(CBPeripheral* peripheral))missingBlock
{
    CBService* desiredService = nil;
    NSLog(@"services");
    for (CBService* service in peripheral.services) {
        NSLog(@"    %@", service.UUID);
        if ([service.UUID isEqual:uuid]) {
            desiredService = service;
            break;
        }
    }
    if (desiredService != nil) {
        if (executeBlock) executeBlock(desiredService, peripheral);
    } else {
        if (missingBlock) missingBlock(peripheral);
    }
}

- (void)characteristicWithUUID:(CBUUID*)uuid
                          from:(CBPeripheral*)peripheral
                       service:(CBService*)service
                     withBlock:(void (^)(CBCharacteristic* characteristic, CBService* service, CBPeripheral* peripheral))executeBlock
                  missingBlock:(void (^)(CBService* service, CBPeripheral* peripheral))missingBlock
{
    CBCharacteristic* desiredCharacteristic = nil;
    NSLog(@"CBCharacteristics (looking for %@)", uuid);
    for (CBCharacteristic* characteristic in service.characteristics) {
        NSLog(@"   %@", characteristic.UUID);
        if ([characteristic.UUID isEqual:uuid]) {
            desiredCharacteristic = characteristic;
            break;
        }
    }
    if (desiredCharacteristic != nil) {
        if (executeBlock) executeBlock(desiredCharacteristic, service, peripheral);
    } else {
        if (missingBlock) missingBlock(service, peripheral);
    }
}



@end
