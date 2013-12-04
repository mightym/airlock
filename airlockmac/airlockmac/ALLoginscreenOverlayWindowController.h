//
//  ALLoginscreenOverlayWindowController.h
//  airlockmac
//
//  Created by Tobias Liebig on 18.11.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ALLoginscreenOverlayWindowController : NSWindowController

- (void)updateStatus:(NSString*)currentStatus;
- (void)updateRssi:(int)value;

@end
