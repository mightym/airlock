//
//  ALAppDelegate.m
//  airlockmac
//
//  Created by Mark Wirblich on 13.11.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALAppDelegate.h"
#import "ALAirlockService.h"
#import "ALLoginscreenOverlayWindowController.h"

@interface ALAppDelegate () {}
@property (strong, nonatomic) ALLoginscreenOverlayWindowController* loginOverlay;
@property (strong, nonatomic) IBOutlet NSSecureTextField* passwordField;
@property (strong, nonatomic) IBOutlet NSSegmentedControl* ibeaconControl;
@property (strong, nonatomic) IBOutlet NSSegmentedControl* peripheralControl;
@end

@implementation ALAppDelegate

- (void)disconnect:(id)sender {}

- (void)awakeFromNib {
    
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setImage:[NSImage imageNamed:@"statusIcon"]];
    [statusItem setAlternateImage:[NSImage imageNamed:@"statusIconInverted"]];
    [statusItem setMenu:statusMenu];
    [statusItem setToolTip:@"Airlock"];
    [statusItem setHighlightMode:YES];
    
    self.ibeaconControl.selectedSegment = 0;
    self.peripheralControl.selectedSegment = 0;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self initializeAirlockService];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    return NSTerminateNow;
}

#pragma mark - init

- (void)initializeAirlockService {
    [[ALAirlockService sharedService] setLoginwindowDidBecomeFrontmostApplicationBlock:^{
        [[[NSAppleScript alloc] initWithSource:@"say \"your mac is now locked!\"\n"] executeAndReturnError:nil];

        self.loginOverlay = [[ALLoginscreenOverlayWindowController alloc] initWithWindowNibName:@"ALLoginscreenOverlayWindowController"];
        [self.loginOverlay.window setLevel:9999];
        [self.loginOverlay showWindow:self];
    }];
    
    [[ALAirlockService sharedService] setLoginwindowDidResignFrontmostApplicationBlock:^{
        [self.loginOverlay close];
        self.loginOverlay = nil;
        [[[NSAppleScript alloc] initWithSource:@"say \"your mac is now unlocked.\"\n"] executeAndReturnError:nil];
    }];
    
//    [[ALAirlockService sharedService] startMonitoring];
//    [[ALAirlockService sharedService] monitorForDevice];
//    [[ALAirlockService sharedService] advertiseAsiBeacon];
}

#pragma mark - Interface Actions

- (IBAction)clickSleepButton:(id)sender
{
    [[ALAirlockService sharedService] lockScreen];
}

- (IBAction)switchIBeacon:(id)sender
{
    NSSegmentedControl* control = (NSSegmentedControl*)sender;
    if (control.selectedSegment == 1) {
        [[ALAirlockService sharedService] startAdvertiseAsiBeacon];
    } {
        [[ALAirlockService sharedService] stopAdvertiseAsiBeacon];
    }
}

- (IBAction)switchPeripheral:(id)sender
{
    NSSegmentedControl* control = (NSSegmentedControl*)sender;
    if (control.selectedSegment == 1) {
        [[ALAirlockService sharedService] startAdvertiseAsPeripheral];
    } {
        [[ALAirlockService sharedService] stopAdvertiseAsPeripheral];
    }
}

#pragma mark - Helper

- (NSString*)userPassword {
    return self.passwordField.stringValue;
}


#pragma mark -


@end
