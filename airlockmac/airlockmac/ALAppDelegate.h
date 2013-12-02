//
//  ALAppDelegate.h
//  airlockmac
//
//  Created by Mark Wirblich on 13.11.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ALAppDelegate : NSObject <NSApplicationDelegate> {

IBOutlet NSMenu *statusMenu;
NSStatusItem *statusItem;
NSImage *statusImage;
NSImage *statusHighlightImage;
}


@property (assign) IBOutlet NSWindow *window;

- (IBAction)disconnect:(id)sender;
- (IBAction)clickSleepButton:(id)sender;
- (NSString*)userPassword;

@end
