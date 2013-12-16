//
//  ALDeviceService.m
//  airlockmac
//
//  Created by Tobias Liebig on 16.12.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALDeviceService.h"

@implementation ALDeviceService

- (void)scanForNearbyDevices
{
    [self performSelector:@selector(foundNewDevice) withObject:nil afterDelay:5.0];
}

- (void)stopScanning
{
    
}

#pragma mark -

- (void)foundNewDevice
{
    if (self.delegate) [self.delegate airlockDeviceService:self didFoundDevice:@"foobar"];
}

@end
