//
//  MainWindowController.h
//  
//
//  Created by Tobias Liebig on 04.12.13.
//
//

#import <Cocoa/Cocoa.h>

@interface ALMainWindowController : NSWindowController


- (IBAction)clickLockButton:(NSButton *)sender;
- (IBAction)rssiToLockValueChanged:(NSSlider *)sender;
- (IBAction)rssiToLoginValueChanged:(NSSlider *)sender;
- (IBAction)loginPasswordChanged:(NSSecureTextFieldCell *)sender;

- (void)updateStatus:(NSString*)currentStatus;
- (void)updateRssi:(int)value;

@end
