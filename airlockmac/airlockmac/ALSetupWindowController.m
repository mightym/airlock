//
//  ALSetupWindowController.m
//  airlockmac
//
//  Created by Tobias Liebig on 16.12.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALSetupWindowController.h"
#import "ALSetupStep2ViewController.h"
#import "ALSetupStep3ViewController.h"
#import "ALSetupStep4ViewController.h"

typedef enum {
	ALSetupStep1,
	ALSetupStep2,
	ALSetupStep3,
    ALSetupStep4,
    ALSetupStep5
} ALSetupStep;


@interface ALSetupWindowController ()

@property (nonatomic, strong) IBOutlet NSBox *boxView;
@property (nonatomic, strong) IBOutlet NSView *innerView;

@property (nonatomic, strong) IBOutlet NSButton *quitButton;

@property (nonatomic, strong) IBOutlet NSViewController *step1ViewController;
@property (nonatomic, strong) IBOutlet ALSetupStep2ViewController *step2ViewController;
@property (nonatomic, strong) IBOutlet ALSetupStep3ViewController *step3ViewController;
@property (nonatomic, strong) IBOutlet ALSetupStep4ViewController *step4ViewController;
@property (nonatomic, strong) IBOutlet NSViewController *step5ViewController;

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
    [self.step2ViewController start];
}

- (void)showStep3
{
    self.currentSetupStep = ALSetupStep3;
    self.boxView.title = @"Step 3";
    [self.step2ViewController stop];
    [self.step2ViewController.view removeFromSuperview];

    [self.innerView addSubview:self.step3ViewController.view];
    [self.step3ViewController start];
}

- (void)showStep4
{
    self.currentSetupStep = ALSetupStep4;
    self.boxView.title = @"Step 4";
    [self.continueButton setEnabled:NO];
    [self.step3ViewController.view removeFromSuperview];
    
    [self.innerView addSubview:self.step4ViewController.view];
    [self.step4ViewController start];
}

- (void)showStep5
{
    self.currentSetupStep = ALSetupStep5;
    self.boxView.title = @"Step 5";
    [self.continueButton setEnabled:NO];
    [self.step4ViewController.view removeFromSuperview];
    
    [self.innerView addSubview:self.step5ViewController.view];
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
            
        case ALSetupStep3:
            [self showStep4];
            break;
            
        case ALSetupStep4:
            [self showStep5];
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
    [alert beginSheetModalForWindow:self.window completionHandler:nil];
}

@end
