//
//  ALDeviceService.h
//  airlockmac
//
//  Created by Tobias Liebig on 16.12.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ALDiscoveredDevice.h"

@protocol ALDeviceServiceDelegate;

@interface ALDeviceService : NSObject

- (void)scanForNearbyDevices;
- (void)stopScanning;

- (NSArray *)devices;

@property (nonatomic, weak) id<ALDeviceServiceDelegate> delegate;

@end



@protocol ALDeviceServiceDelegate <NSObject>

@required
- (void)airlockDeviceService:(ALDeviceService*)service didFoundDevice:(ALDiscoveredDevice*)device;
- (void)airlockDeviceService:(ALDeviceService*)service didRemoveDeviceWithIdentifier:(NSUUID*)identifier;
- (void)airlockDeviceService:(ALDeviceService*)service didUpdateDevice:(ALDiscoveredDevice*)device;

@end


