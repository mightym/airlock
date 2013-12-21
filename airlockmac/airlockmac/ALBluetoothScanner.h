//
//  ALBluetoothScanner.h
//  airlockmac
//
//  Created by Tobias Liebig on 18.12.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <IOBluetooth/IOBluetooth.h>

extern NSString *const kALNotificationsBluetoothServiceDidFoundNewDeviceNotification;
extern NSString *const kALNotificationsBluetoothServiceDeviceDisappearedNotification;
extern NSString *const kALNotificationsBluetoothServiceDeviceUpdatedNotification;

typedef enum {
	ALAirlockCharacteristicChallengeCharacteristic,
    ALAirlockCharacteristicChallengeResponseCharacteristic
} ALAirlockCharacteristic;

@interface ALBluetoothScanner : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (strong, nonatomic) NSMutableDictionary *discovered;

+ (instancetype)sharedService;

- (void)startScanning;
- (void)stopScanning;

- (void)read:(ALAirlockCharacteristic)characteristicToRead from:(CBPeripheral*)peripheral callback:(void(^)(NSData* value))callback;
- (void)write:(ALAirlockCharacteristic)characteristicToWrite to:(CBPeripheral*)peripheral value:(NSData*)value callback:(void(^)(NSData* newValue))callback;

@end
