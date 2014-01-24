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

- (void)sendRequest:(NSString*)request toDevice:(ALDiscoveredDevice*)device callback:(void (^)(NSData *response))callback failed:(void (^)(void))failedCallback;

- (NSArray *)devices;

@property (nonatomic, weak) id<ALDeviceServiceDelegate> delegate;

@end



@protocol ALDeviceServiceDelegate <NSObject>

@optional
- (void)airlockDeviceService:(ALDeviceService*)service didFoundDevice:(ALDiscoveredDevice*)device;
- (void)airlockDeviceService:(ALDeviceService*)service didRemoveDeviceWithIdentifier:(NSUUID*)identifier;
- (void)airlockDeviceService:(ALDeviceService*)service didUpdateDevice:(ALDiscoveredDevice*)device;

@end


