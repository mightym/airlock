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
        ALDiscoveredDevice* device = (ALDiscoveredDevice*)[notification.userInfo objectForKey:@"newDevice"];
        if (self.delegate) [self.delegate airlockDeviceService:self
                                                didFoundDevice:device];
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

- (void)sendPairingChallenge:(ALDiscoveredDevice*)device callback:(void (^)(void))callback
{
    [[ALBluetoothScanner sharedService] read:ALAirlockCharacteristicChallengeCharacteristic
                                        from:device.peripheral
                                    callback:^void (NSData* value) {
                                        NSLog(@"value %@", value);
                                        NSString *incomingChallenge = [[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding];
                                        NSString *outgoingChallenge = [ALChallengeHelper generateNewChallenge];
                                        NSString *challengeResponse = [ALChallengeHelper calculateResponseForIncomingChallenge:incomingChallenge
                                                                                                             outgoingChallenge:outgoingChallenge];
                                        [[ALBluetoothScanner sharedService] write:ALAirlockCharacteristicChallengeResponseCharacteristic
                                                                               to:device.peripheral
                                                                            value:[challengeResponse dataUsingEncoding:NSUTF8StringEncoding]
                                                                         callback:^{
                                                                             NSLog(@"challengeResponse written");
                                                                         } responseCallback:^(NSString * response) {
                                                                             NSLog(@"response %@", response);
                                                                             NSArray *chunks = [response componentsSeparatedByString:@"."];
                                                                             NSString *challengeResponse = chunks.firstObject;
                                                                             NSString *newIncomingChallenge = chunks.lastObject;

                                                                             NSString *expecedResponse = [ALChallengeHelper calculateResponseForIncomingChallenge:outgoingChallenge
                                                                                                                                                         outgoingChallenge:newIncomingChallenge];
                                                                             if ([response isEqualToString:expecedResponse])
                                                                             {
                                                                                 if (callback) callback();
                                                                             } else {
                                                                                dispatch_sync(dispatch_get_main_queue(), ^{
                                                                                    NSAlert *alert = [NSAlert alertWithMessageText:@"An error occurred" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"foobar"];
                                                                                    [alert runModal]; // beginSheetModalForWindow:nil completionHandler:nil];
                                                                                });
                                                                             }
                                                                         }];
                                    }];
}

@end
