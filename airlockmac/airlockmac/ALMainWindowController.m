//
//  MainWindowController.m
//  
//
//  Created by Tobias Liebig on 04.12.13.
//
//

#import "ALMainWindowController.h"
#import "ALAirlockService.h"

@interface ALMainWindowController ()
@property (strong) IBOutlet NSSecureTextField *loginPasswordField;
@property (strong) IBOutlet NSSlider *rssiToLockSlider;
@property (strong) IBOutlet NSSlider *rssiToLoginSlider;
@property (strong) IBOutlet NSTextField *rssiToLockLabel;
@property (strong) IBOutlet NSTextField *rssiToLoginLabel;
@property (strong) IBOutlet NSTextField *statusLabel;
@property (strong) IBOutlet NSProgressIndicator *statusProgressIndicator;
@property (strong) IBOutlet NSTextField *statusRssiLabel;
@property (strong) IBOutlet NSTextView *debugView;

@end

@implementation ALMainWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [self rssiToLockValueChanged:self.rssiToLockSlider];
    [self rssiToLoginValueChanged:self.rssiToLoginSlider];
}

- (IBAction)clickLockButton:(NSButton *)sender {
    [[ALAirlockService sharedService] performLockScreen];
}

- (IBAction)rssiToLockValueChanged:(NSSlider *)sender {
    if ((long)sender.intValue > self.rssiToLoginSlider.intValue) {
        sender.intValue = self.rssiToLoginSlider.intValue;
    }
    self.rssiToLockLabel.stringValue = [NSString stringWithFormat:@"%ld dB", (long)sender.intValue];
    [[ALAirlockService sharedService] setRSSIMinimumToDisconnect:sender.intValue];
}

- (IBAction)rssiToLoginValueChanged:(NSSlider *)sender {
    if ((long)sender.intValue < self.rssiToLockSlider.intValue) {
        sender.intValue = self.rssiToLockSlider.intValue;
    }
    self.rssiToLoginLabel.stringValue = [NSString stringWithFormat:@"%ld dB", (long)sender.intValue];
    [[ALAirlockService sharedService] setRSSIMinimumToConnect:sender.intValue];
}

- (IBAction)loginPasswordChanged:(NSSecureTextFieldCell *)sender {
     // TODO save in keychain instead
    [[ALAirlockService sharedService] setPassword:sender.stringValue];
}

- (void)updateStatus:(NSString*)currentStatus
{
    // TODO use an enumeration instead of a string
    self.statusLabel.stringValue = currentStatus;
    if ([currentStatus isEqualToString:@"initialize"] || [currentStatus isEqualToString:@"discover"]) {
        [self.statusProgressIndicator startAnimation:self];
    } else {
        [self.statusProgressIndicator stopAnimation:self];
    }
}

- (void)updateRssi:(int)value
{
    self.statusRssiLabel.stringValue = (value == 0) ? @"" : [NSString stringWithFormat:@"%ld dB", (long)value];
}

- (void)setDebug:(NSString*)debug {
    self.debugView.string = debug;
}

@end
