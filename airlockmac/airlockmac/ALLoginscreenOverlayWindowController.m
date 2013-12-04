//
//  ALLoginscreenOverlayWindowController.m
//  airlockmac
//
//  Created by Tobias Liebig on 18.11.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALLoginscreenOverlayWindowController.h"
#import "ALAirlockService.h"

@interface ALLoginscreenOverlayWindowController ()

@property (strong) IBOutlet NSTextField *statusLabel;
@property (strong) IBOutlet NSTextField *statusRssiLabel;

@end

@implementation ALLoginscreenOverlayWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [self.window setLevel:9999];
}


- (void)updateStatus:(NSString*)currentStatus
{
    // TODO use an enumeration instead of a string
    self.statusLabel.stringValue = currentStatus;
    if ([currentStatus isEqualToString:@"initialize"] || [currentStatus isEqualToString:@"discover"]) {
    } else {
    }
}

- (void)updateRssi:(int)value
{
    self.statusRssiLabel.stringValue = (value == 0) ? @"" : [NSString stringWithFormat:@"%ld dB", (long)value];
}

@end
