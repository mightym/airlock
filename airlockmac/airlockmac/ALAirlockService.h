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

@property (nonatomic, copy) void (^connectedPeripheralLeavesRange)(void);
@property (nonatomic, copy) void (^connectedPeripheralEntersRange)(void);

+ (instancetype)sharedService;

- (void)start;
- (void)stop;
- (void)loginUser;
- (void)lockScreen;

@end
