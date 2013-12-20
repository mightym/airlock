//
//  ALSetupStep2ViewController.m
//  airlockmac
//
//  Created by Tobias Liebig on 16.12.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALSetupStep2ViewController.h"

@interface ALSetupStep2ViewController ()

@property (nonatomic, strong) IBOutlet NSProgressIndicator *progressIndicator;
@property (nonatomic, strong) IBOutlet NSTextField *statusLabel;
@property (nonatomic, strong) ALDeviceService *deviceService;

@end

@implementation ALSetupStep2ViewController

- (void)awakeFromNib
{
}

- (void)start {
    [self scanForDevices];
}

- (void)stop {
    if (self.deviceService == nil) [self.deviceService stopScanning];
}

#pragma mark -
- (void) scanForDevices
{
    self.statusLabel.stringValue = @"Scanning for an iPhone with Airlock nearby...";
    [self.statusLabel setHidden:NO];
    [self.progressIndicator setHidden:NO];
    [self.progressIndicator startAnimation:self];

    if (self.deviceService == nil) self.deviceService = [[ALDeviceService alloc] init];
    self.deviceService.delegate = self;
    [self.deviceService scanForNearbyDevices];
}

#pragma mark - ALDeviceServiceDelegate

- (void)airlockDeviceService:(ALDeviceService *)service didFoundDevice:(ALDiscoveredDevice *)device
{
    self.statusLabel.stringValue = @"checking nearby devices...";
}

- (void)airlockDeviceService:(ALDeviceService *)service didUpdateDevice:(ALDiscoveredDevice *)device
{
    [service stopScanning];
    [self.progressIndicator setHidden:YES];
    if (self.setupWindowController) [self.setupWindowController showNext];
}

- (void)airlockDeviceService:(ALDeviceService *)service didRemoveDeviceWithIdentifier:(NSUUID *)identifier
{
}

#pragma mark - Interface Actions

- (IBAction)notYetImplementedAction:(id)sender
{
    NSAlert *alert = [NSAlert alertWithMessageText:@"Not yet implemented" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"foobar"];
    [alert beginSheetModalForWindow:self.setupWindowController.window completionHandler:nil];
}

@end
