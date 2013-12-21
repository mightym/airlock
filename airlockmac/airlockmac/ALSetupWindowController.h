//
//  ALSetupWindowController.h
//  airlockmac
//
//  Created by Tobias Liebig on 16.12.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ALDiscoveredDevice.h"

@interface ALSetupWindowController : NSWindowController

@property (nonatomic, strong) IBOutlet NSButton *continueButton;
@property (nonatomic, strong) ALDiscoveredDevice *selectedDevice;

- (void)showNext;

@end
