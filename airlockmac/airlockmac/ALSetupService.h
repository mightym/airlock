//
//  ALSetupService.h
//  airlockmac
//
//  Created by Tobias Liebig on 16.12.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ALSetupService : NSObject

+ (instancetype)sharedService;
- (BOOL)hasValidSetup;
- (void)startSetup;

@end
