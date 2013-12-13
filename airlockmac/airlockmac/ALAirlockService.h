//
//  ALAirlockService.h
//  airlockmac
//
//  Created by Tobias Liebig on 18.11.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>


@protocol ALAirlockServiceDelegate;

@interface ALAirlockService : NSObject

@property (nonatomic, weak) id <ALAirlockServiceDelegate> delegate;

@property (nonatomic, strong) NSString* password; // TODO get from keychain instead
@property (nonatomic) int RSSIMinimumToConnect;
@property (nonatomic) int RSSIMinimumToDisconnect;

+ (instancetype)sharedService;

- (void)startWithDelegate:(id<ALAirlockServiceDelegate>)theDelegate;
- (void)stop;
- (void)performLogin;
- (void)performLockScreen;

@end

@protocol ALAirlockServiceDelegate <NSObject>

@required
- (void)airlockService:(ALAirlockService*)service didUpdateStatus:(NSString*)currentStatus;
- (void)airlockService:(ALAirlockService *)service didUpdateRSSI:(int)rssiValue;

@optional
- (void)airlockServiceLoginwindowDidBecomeFrontmostApplication:(ALAirlockService *)service;
- (void)airlockServiceLoginwindowDidResignFrontmostApplication:(ALAirlockService *)service;

@end
