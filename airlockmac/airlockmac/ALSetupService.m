//
//  ALSetupService.m
//  airlockmac
//
//  Created by Tobias Liebig on 16.12.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALSetupService.h"
#import "ALSetupWindowController.h"
#import "ALAppDelegate.h"

@interface ALSetupService ()
@property (strong, nonatomic) ALSetupWindowController *setupWindowController;
@end

@implementation ALSetupService

+ (instancetype)sharedService
{
    static ALSetupService *_sharedService = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedService = [[self alloc] init];
    });
    
    return _sharedService;
}

- (BOOL)hasValidSetup
{
    return NO;
}

- (void)startSetup
{
    self.setupWindowController = [[ALSetupWindowController alloc] initWithWindowNibName:@"ALSetupWindowController"];
    ALAppDelegate *applicationDelegate = (ALAppDelegate*)[NSApplication sharedApplication].delegate;
    [self.setupWindowController showWindow:applicationDelegate];
    [self.setupWindowController.window makeKeyAndOrderFront:applicationDelegate];
}


@end
