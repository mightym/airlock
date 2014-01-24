//
//  ALSetupStep4ViewController.m
//  airlockmac
//
//  Created by Tobias Liebig on 21.12.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALSetupStep4ViewController.h"
#import "ALBluetoothScanner.h"

@interface ALSetupStep4ViewController ()

@end

@implementation ALSetupStep4ViewController

- (void)start {
    if (self.setupWindowController.selectedDevice) {
        [[ALBluetoothScanner sharedService] stopScanning];
        
        [self.setupWindowController.selectedDevice sendPairingRequestAndCallback:^{
            [self.setupWindowController showNext];
        }
                                                                          failed:^{
            dispatch_sync(dispatch_get_main_queue(), ^{
                NSAlert *alert = [NSAlert alertWithMessageText:@"An error occurred" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"foobar"];
                [alert beginSheetModalForWindow:self.setupWindowController.window completionHandler:nil];
            });
        }];
    }
}

- (void)stop {

}

@end
