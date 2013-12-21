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

- (void)sendPairingChallenge:(ALDiscoveredDevice*)device
{
    [[ALBluetoothScanner sharedService] read:ALAirlockCharacteristicChallengeCharacteristic
                                        from:device.peripheral
                                    callback:^void (NSData* value) {
                                        NSString *incomingChallenge = [[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding];
                                        NSString *challengeResponse = [ALChallengeHelper calculateResponseForIncomingChallenge:incomingChallenge
                                                                                                             outgoingChallenge:[ALChallengeHelper generateNewChallenge]];
                                        [NSAlert alertWithMessageText:@"yay"
                                                        defaultButton:@"Okay"
                                                      alternateButton:nil otherButton:nil informativeTextWithFormat:nil];
                                    }];
}

@end
