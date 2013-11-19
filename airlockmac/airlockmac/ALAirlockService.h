//
//  ALAirlockService.h
//  airlockmac
//
//  Created by Tobias Liebig on 18.11.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ALAirlockService : NSObject

@property (nonatomic, copy) void (^loginwindowDidBecomeFrontmostApplicationBlock)(void);
@property (nonatomic, copy) void (^loginwindowDidResignFrontmostApplicationBlock)(void);

+ (instancetype)sharedService;
- (void)startMonitoring;
- (void)loginUser;
- (void)lockScreen;

@end
