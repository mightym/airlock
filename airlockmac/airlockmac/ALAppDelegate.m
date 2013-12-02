//
//  ALAppDelegate.m
//  airlockmac
//
//  Created by Mark Wirblich on 13.11.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALAppDelegate.h"
#import "ALAirlockService.h"

@interface ALAppDelegate () {}
@property (strong, nonatomic) IBOutlet NSSecureTextField* passwordField;

@property (strong, nonatomic) IBOutlet NSTextField* statusLabel;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressIndicator;

@property (strong, nonatomic) IBOutlet NSSegmentedControl* discoverControl;
@end

@implementation ALAppDelegate

- (void)disconnect:(id)sender {}

- (void)awakeFromNib {
    
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setImage:[NSImage imageNamed:@"statusIcon"]];
    [statusItem setAlternateImage:[NSImage imageNamed:@"statusIconInverted"]];
    [statusItem setMenu:statusMenu];
    [statusItem setToolTip:@"Airlock"];
    [statusItem setHighlightMode:NO];
    
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self initializeAirlockService];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    [[ALAirlockService sharedService] stop];
    // TODO
    return NSTerminateNow;
}

#pragma mark - init

- (void)initializeAirlockService {
    self.statusLabel.stringValue = @"initialize";
    [self.progressIndicator startAnimation:self];

    [[ALAirlockService sharedService] start];

    /*
     NSSegmentedControl* control = (NSSegmentedControl*)sender;
     if (control.selectedSegment == 1) {
     [[ALAirlockService sharedService] discoverAirlockOnIOS];
     } {
     [[ALAirlockService sharedService] stopDiscoverAirlockOnIOS];
     }
    */
}

#pragma mark - Interface Actions

- (IBAction)clickSleepButton:(id)sender
{
    [[ALAirlockService sharedService] lockScreen];
}

#pragma mark - Helper

- (NSString*)userPassword {
    return self.passwordField.stringValue;
}

@end
