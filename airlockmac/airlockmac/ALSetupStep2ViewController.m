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

@end

@implementation ALSetupStep2ViewController

- (void)awakeFromNib
{
    [self scanForDevices];
}


#pragma mark - 
- (void) scanForDevices
{
    self.statusLabel.stringValue = @"Scanning for an iPhone with Airlock nearby...";
    [self.statusLabel setHidden:NO];
    [self.progressIndicator setHidden:NO];
    [self.progressIndicator startAnimation:self];
    ALDeviceService *deviceService = [[ALDeviceService alloc] init];
    deviceService.delegate = self;
    [deviceService scanForNearbyDevices];
}

#pragma mark - ALDeviceServiceDelegate

- (void)airlockDeviceService:(ALDeviceService *)service didFoundDevice:(NSString *)uuid
{
    [service stopScanning];
    [self.progressIndicator setHidden:YES];
    self.statusLabel.stringValue = @"iPhone with Airlock found!";
    if (self.setupWindowController) [self.setupWindowController showNext];
}

#pragma mark - Interface Actions

- (IBAction)clickDownloadButton:(id)sender
{
    [self notYetImplementedAction:sender];
}

- (IBAction)notYetImplementedAction:(id)sender
{
    NSAlert *alert = [NSAlert alertWithMessageText:@"Not yet implemented" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"foobar"];
    [alert runModal];
}

@end
