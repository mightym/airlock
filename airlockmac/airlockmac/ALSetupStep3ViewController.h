//
//  ALSetupStep3ViewController.h
//  airlockmac
//
//  Created by Tobias Liebig on 17.12.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ALDeviceService.h"
#import "ALSetupWindowController.h"

@interface ALSetupStep3ViewController : NSViewController <ALDeviceServiceDelegate, NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, weak) IBOutlet ALSetupWindowController* setupWindowController;

- (void)start;
- (void)stop;

@end
