//
//  ALDiscoveredPeripheral.m
//  airlockmac
//
//  Created by Tobias Liebig on 18.12.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALDiscoveredDevice.h"
#import "ALDeviceHelper.h"
#import "ALDeviceService.h"

@implementation ALDiscoveredDevice

- (NSString*)description
{
    return [NSString stringWithFormat:@"%@ - %@",
            [self.deviceName isEqualToString:@""] ? @"<unknown>" : self.deviceName,
            [ALDeviceHelper platformString:self.platform]];
}

- (void)sendPairingRequestAndCallback:(void (^)(void))callback {
    ALDeviceService* deviceService = [[ALDeviceService alloc] init];
    [deviceService sendPairingChallenge:self];
}

@end
