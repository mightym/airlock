//
//  ALDiscoveredPeripheral.m
//  airlockmac
//
//  Created by Tobias Liebig on 18.12.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALDiscoveredDevice.h"

@implementation ALDiscoveredDevice

- (NSString*)description
{
    return [self.identifier UUIDString];
}

@end