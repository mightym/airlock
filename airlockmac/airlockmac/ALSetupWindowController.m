//
//  ALSetupWindowController.m
//  airlockmac
//
//  Created by Tobias Liebig on 16.12.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALSetupWindowController.h"

typedef enum {
	ALSetupStep1,
	ALSetupStep2
} ALSetupStep;


@interface ALSetupWindowController ()

@property (nonatomic, strong) IBOutlet NSView *innerView;

@property (nonatomic, strong) IBOutlet NSViewController *step1ViewController;

@property ALSetupStep currentSetupStep;

@end

@implementation ALSetupWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        self.currentSetupStep = ALSetupStep1;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [self showStep1];
}

#pragma mark - Setup steps

- (void)showStep1
{
    self.currentSetupStep = ALSetupStep1;
    [self.innerView addSubview:self.step1ViewController.view];
}

- (void)showStep2
{
    self.currentSetupStep = ALSetupStep2;
    [self.step1ViewController.view removeFromSuperview];
}


#pragma mark - Interface Actions

- (IBAction)clickQuit:(id)sender
{
    NSAlert *alert = [NSAlert alertWithMessageText:@"Not yet implemented" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"foobar"];
    [alert runModal];
}

- (IBAction)clickContinue:(id)sender
{
    switch (self.currentSetupStep) {
        case ALSetupStep1:
            [self showStep2];
            break;
            
        default:
            break;
    }
}

@end
