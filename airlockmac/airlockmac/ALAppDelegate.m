//
//  ALAppDelegate.m
//  airlockmac
//
//  Created by Mark Wirblich on 13.11.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALAppDelegate.h"
#import "ALSetupService.h"

@interface ALAppDelegate () {}
@property (nonatomic) NSString *lastStatus;
@end

@implementation ALAppDelegate

- (void)awakeFromNib {
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self initializeStatusIcon];
//    [self initializeAirlockService];
//    [self initializeMainWindow];
    [self setup];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    [[ALAirlockService sharedService] stop];
    // TODO
    return NSTerminateNow;
}

#pragma mark - init

- (void)initializeStatusIcon {
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setImage:[NSImage imageNamed:@"statusIcon"]];
    [statusItem setAlternateImage:[NSImage imageNamed:@"statusIconInverted"]];
    [statusItem setMenu:statusMenu];
    [statusItem setToolTip:@"Airlock"];
    [statusItem setHighlightMode:NO];
}

- (void)initializeAirlockService {
    ALAirlockService *airlockService = [ALAirlockService sharedService];
    [airlockService startWithDelegate:self];
    airlockService.RSSIMinimumToConnect = 0;
    airlockService.RSSIMinimumToDisconnect = 0;

    /*
     NSSegmentedControl* control = (NSSegmentedControl*)sender;
     if (control.selectedSegment == 1) {
     [[ALAirlockService sharedService] discoverAirlockOnIOS];
     } {
     [[ALAirlockService sharedService] stopDiscoverAirlockOnIOS];
     }
    */
}

- (void)initializeMainWindow {
    mainWindowController = [[ALMainWindowController alloc] initWithWindowNibName:@"ALMainWindowController"];
    [mainWindowController showWindow:self];
    [mainWindowController.window makeKeyAndOrderFront:self];
}

- (void)setup {
    if (![[ALSetupService sharedService] hasValidSetup]) {
        [[ALSetupService sharedService] startSetup];
    }
}

#pragma mark - ALAirlockServiceDelegate

- (void)airlockService:(ALAirlockService *)service didUpdateStatus:(NSString *)currentStatus
{
    self.lastStatus = currentStatus;
    if (mainWindowController) [mainWindowController updateStatus:currentStatus];
    if (loginscreenOverlayWindowController) [loginscreenOverlayWindowController updateStatus:currentStatus];
}

- (void)airlockService:(ALAirlockService *)service didUpdateRSSI:(int)rssiValue
{
    if (mainWindowController) [mainWindowController updateRssi:rssiValue];
    if (loginscreenOverlayWindowController) [loginscreenOverlayWindowController updateRssi:rssiValue];
}

- (void)airlockServiceLoginwindowDidBecomeFrontmostApplication:(ALAirlockService *)service
{
    loginscreenOverlayWindowController = [[ALLoginscreenOverlayWindowController alloc] initWithWindowNibName:@"ALLoginscreenOverlayWindowController"];
    [loginscreenOverlayWindowController showWindow:self];
    [loginscreenOverlayWindowController updateStatus:self.lastStatus];
}

- (void)airlockServiceLoginwindowDidResignFrontmostApplication:(ALAirlockService *)service
{
    [loginscreenOverlayWindowController close];
    loginscreenOverlayWindowController = nil;
}

- (void)setDebug:(NSString*)debug {
    if (mainWindowController) [mainWindowController setDebug:debug];
}

@end
