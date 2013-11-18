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
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (IBAction)clickPretendIphoneIsNearButton:(id)sender {
    ALAirlockService *airlockService = [[ALAirlockService alloc] init];
    [airlockService loginUser];
}

@end
