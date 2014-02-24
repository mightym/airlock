//
//  ALDeviceService.m
//  airlockmac
//
//  Created by Tobias Liebig on 16.12.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALDeviceService.h"
#import "ALBluetoothScanner.h"
#import "ALDiscoveredDevice.h"
#import "ALChallengeHelper.h"

#import "NSData+AESAdditions.h"

@implementation ALDeviceService

- (void)scanForNearbyDevices
{
    // [self performSelector:@selector(foundNewDevice) withObject:nil afterDelay:5.0];
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center addObserver:self
			   selector:@selector(foundNewDevice:)
				   name:kALNotificationsBluetoothServiceDidFoundNewDeviceNotification
				 object:nil];
    
	[center addObserver:self
			   selector:@selector(deviceDisappeared:)
				   name:kALNotificationsBluetoothServiceDeviceDisappearedNotification
				 object:nil];
    
	[center addObserver:self
			   selector:@selector(deviceUpdated:)
				   name:kALNotificationsBluetoothServiceDeviceUpdatedNotification
				 object:nil];
    
    [[ALBluetoothScanner sharedService] startScanning];
}

- (void)stopScanning
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self];
}

#pragma mark -

- (NSArray *)devices
{
    return [[[ALBluetoothScanner sharedService] discovered] allValues];
}

- (void)deviceDisappeared:(NSNotification *)notification
{
    if ([notification.userInfo objectForKey:@"identifier"]) {
        NSUUID* identifier = (NSUUID*)[notification.userInfo objectForKey:@"identifier"];
        if (self.delegate) [self.delegate airlockDeviceService:self didRemoveDeviceWithIdentifier:identifier];
    }
}

- (void)foundNewDevice:(NSNotification *)notification
{
    if ([notification.userInfo objectForKey:@"newDevice"]) {
        __block ALDeviceService* blockself = self;
        __block ALDiscoveredDevice* device = (ALDiscoveredDevice*)[notification.userInfo objectForKey:@"newDevice"];
        if (self.delegate) [self.delegate airlockDeviceService:self
                                                didFoundDevice:device];
        
        [self sendRequest:@"deviceName" toDevice:device callback:^(NSData *response) {
            NSLog(@"response %@", response);
            NSString *salt = [[NSString alloc] initWithData:[response subdataWithRange:NSMakeRange([response length] - 32, 32)] encoding:NSUTF8StringEncoding];
            NSData *cryptedData = [response subdataWithRange:NSMakeRange(0, [response length] - 32)];
            
            NSString *reply = [[NSString alloc] initWithData:[cryptedData AES256DecryptWithKey:@"4C2C93388CC841BB9BB69811CC0483E9" iv:salt] encoding:NSUTF8StringEncoding];
            
            device.deviceName = reply;
            NSLog(@"%@", device.deviceName);
            
            if (blockself.delegate) [blockself.delegate airlockDeviceService:blockself
                                                   didUpdateDevice:device];
        } failed:^{
            
        }];

    }
}

- (void)deviceUpdated:(NSNotification *)notification
{
    if ([notification.userInfo objectForKey:@"updatedDevice"]) {
        ALDiscoveredDevice* device = (ALDiscoveredDevice*)[notification.userInfo objectForKey:@"updatedDevice"];
        if (self.delegate) [self.delegate airlockDeviceService:self
                                               didUpdateDevice:device];
    }
}

#pragma mark -

- (void)sendRequest:(NSString*)request toDevice:(ALDiscoveredDevice*)device callback:(void (^)(NSData *response))callback failed:(void (^)(void))failedCallback
{

    NSString* salt = [ALChallengeHelper generateRandomString:32];
    NSData* cryptedRequest = [[request dataUsingEncoding:NSUTF8StringEncoding] AES256EncryptWithKey:@"4C2C93388CC841BB9BB69811CC0483E9" iv:salt];
    NSMutableData* cryptedRequestWithSalt = [cryptedRequest mutableCopy];
    [cryptedRequestWithSalt appendData:[[NSString stringWithFormat:@"%@", salt] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [[ALBluetoothScanner sharedService] write:ALAirlockCharacteristicCryptedInterfaceCharacteristic
                                           to:device.peripheral
                                        value:cryptedRequestWithSalt
                             responseCallback:^(NSData *response) {
                                 if (callback) callback(response);
                             }];
}

@end
