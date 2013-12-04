//
//  ALAppDelegate.m
//  airlockmac
//
//  Created by Mark Wirblich on 13.11.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALAppDelegate.h"

@interface ALAppDelegate () {}
@property (strong, nonatomic) IBOutlet NSSecureTextField* passwordField;

@property (strong, nonatomic) IBOutlet NSTextField* statusLabel;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressIndicator;

@property (strong, nonatomic) IBOutlet NSSegmentedControl* discoverControl;
@end

@implementation ALAppDelegate

- (void)disconnect:(id)sender {}

- (void)awakeFromNib {
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self initializeStatusIcon];
    [self initializeAirlockService];
    [self initializeMainWindow];
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

#pragma mark - ALAirlockServiceDelegate

- (void)airlockService:(ALAirlockService *)service didUpdateStatus:(NSString *)currentStatus
{
    if (mainWindowController) {
        [mainWindowController updateStatus:currentStatus];
    }
}

- (void)airlockService:(ALAirlockService *)service didUpdateRSSI:(int)rssiValue
{
    if (mainWindowController) {
        [mainWindowController updateRssi:rssiValue];
    }
}


@end
