//
//  ALSetupStep2ViewController.h
//  airlockmac
//
//  Created by Tobias Liebig on 16.12.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ALDeviceService.h"
#import "ALSetupWindowController.h"

@interface ALSetupStep2ViewController : NSViewController <ALDeviceServiceDelegate>

@property (nonatomic, weak) IBOutlet ALSetupWindowController* setupWindowController;

@end
