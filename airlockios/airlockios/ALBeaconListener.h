//
//  ALBeaconListener.h
//  airlockios
//
//  Created by Tobias Liebig on 26.02.14.
//  Copyright (c) 2014 Mark Wirblich. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <CoreLocation/CoreLocation.h>

@interface ALBeaconListener : NSObject

- (id)initWithUUID:(NSUUID*)beaconUUID;
- (id)initWithUUID:(NSUUID*)beaconUUID major:(CLBeaconMajorValue)major;
- (id)initWithUUID:(NSUUID*)beaconUUID major:(CLBeaconMajorValue)major minor:(CLBeaconMinorValue)minor;

- (void)start;

@end
