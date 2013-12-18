//
//  ALDiscoveredPeripheral.h
//  airlockmac
//
//  Created by Tobias Liebig on 18.12.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <IOBluetooth/IOBluetooth.h>

@interface ALDiscoveredDevice : NSObject

@property (nonatomic, strong) NSUUID *identifier;
@property (nonatomic, strong) CBPeripheral *peripheral;
@property (nonatomic, strong) NSNumber *lastRSSI;
@property (nonatomic, strong) NSDate *lastSeen;

- (NSString*)description;

@end
