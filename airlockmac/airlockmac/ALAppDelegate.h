//
//  ALAppDelegate.h
//  airlockmac
//
//  Created by Mark Wirblich on 13.11.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ALMainWindowController.h"
#import "ALAirlockService.h"

@interface ALAppDelegate : NSObject <NSApplicationDelegate, ALAirlockServiceDelegate> {

    IBOutlet NSMenu *statusMenu;
    NSStatusItem *statusItem;
    NSImage *statusImage;
    NSImage *statusHighlightImage;

    ALMainWindowController *mainWindowController;
    
}


@property (assign) IBOutlet NSWindow *window;

- (IBAction)disconnect:(id)sender;

@end
