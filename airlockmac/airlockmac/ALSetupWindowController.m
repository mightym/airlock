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
	ALSetupStep2,
	ALSetupStep3
} ALSetupStep;


@interface ALSetupWindowController ()

@property (nonatomic, strong) IBOutlet NSBox *boxView;
@property (nonatomic, strong) IBOutlet NSView *innerView;

@property (nonatomic, strong) IBOutlet NSButton *quitButton;
@property (nonatomic, strong) IBOutlet NSButton *continueButton;

@property (nonatomic, strong) IBOutlet NSViewController *step1ViewController;
@property (nonatomic, strong) IBOutlet NSViewController *step2ViewController;
@property (nonatomic, strong) IBOutlet NSViewController *step3ViewController;

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
    self.boxView.title = @"Step 1";
    [self.innerView addSubview:self.step1ViewController.view];
}

- (void)showStep2
{
    self.currentSetupStep = ALSetupStep2;
    self.boxView.title = @"Step 2";
    [self.continueButton setEnabled:NO];
    [self.step1ViewController.view removeFromSuperview];
    [self.innerView addSubview:self.step2ViewController.view];
}

- (void)showStep3
{
    self.currentSetupStep = ALSetupStep3;
    self.boxView.title = @"Step 3";
    [self.step2ViewController.view removeFromSuperview];
    [self.innerView addSubview:self.step3ViewController.view];
}

- (void)showNext
{
    switch (self.currentSetupStep) {
        case ALSetupStep1:
            [self showStep2];
            break;
            
        case ALSetupStep2:
            [self showStep3];
            break;
            
        default:
            break;
    }
}

#pragma mark - Interface Actions

- (IBAction)clickQuit:(id)sender
{
    [self notYetImplementedAction:sender];
}

- (IBAction)clickContinue:(id)sender
{
    [self showNext];
}

- (IBAction)notYetImplementedAction:(id)sender
{
    NSAlert *alert = [NSAlert alertWithMessageText:@"Not yet implemented" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"foobar"];
    [alert runModal];
}

@end
