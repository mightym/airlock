//
//  ALAirlockService.m
//  airlockmac
//
//  Created by Tobias Liebig on 18.11.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALAirlockService.h"
#import "ALAppDelegate.h"
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>

@interface ALAirlockService () {}
    @property BOOL loginwindowIsFrontmostApplication;
@end

@implementation ALAirlockService

-(id)init {
    self = [super init];
    if (self) {
        self.loginwindowIsFrontmostApplication = NO;
    }
    return self;
}

- (void)startMonitoring {
    /*
     [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(receiveSleepNote:) name:NSWorkspaceScreensDidSleepNotification object:NULL];
     [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(receiveWakeNote:) name:NSWorkspaceScreensDidWakeNotification object:NULL];
     */
    
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(fireWatchWorkspaceTimer:) userInfo:nil repeats:YES];
    [timer setTolerance:1.0];
}

- (void)fireWatchWorkspaceTimer:(NSTimer*)theTimer {

    if ([[[[NSWorkspace sharedWorkspace] frontmostApplication] bundleIdentifier] isEqualToString:@"com.apple.loginwindow"]) {
        if (!self.loginwindowIsFrontmostApplication
            && self.loginwindowDidBecomeFrontmostApplicationBlock) {
                self.loginwindowDidBecomeFrontmostApplicationBlock();
        }
        self.loginwindowIsFrontmostApplication = YES;
    } else {
        if (self.loginwindowIsFrontmostApplication
            && self.loginwindowDidLoseFrontmostApplicationBlock) {
            self.loginwindowDidLoseFrontmostApplicationBlock();
        }
        self.loginwindowIsFrontmostApplication = NO;
    }
    
}


- (void)loginUser {
    ALAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    NSAppleScript *enterPasswordScript = [[NSAppleScript alloc] initWithSource:
                                          [NSString stringWithFormat:@"say \"login\"\ntell application \"System Events\"\n keystroke \"%@\"\nkeystroke return\nend tell", [appDelegate userPassword]]];
    [enterPasswordScript executeAndReturnError:nil];
}


+ (void)sendMacToSleep {
    /*
     NSAppleScript *script = [[NSAppleScript alloc] initWithSource:@"tell application \"System Events\" to sleep"];
     NSDictionary *errorInfo;
     [script executeAndReturnError:&errorInfo];
     */
    
    /*
     [self runCommand:@"/System/Library/CoreServices/Menu\\ Extras/User.menu/Contents/Resources/CGSession -suspend"];
     */
}


+ (NSString*)runCommand:(NSString *)commandToRun
{
    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath: @"/bin/sh"];
    
    NSArray *arguments = [NSArray arrayWithObjects:
                          @"-c" ,
                          [NSString stringWithFormat:@"%@", commandToRun],
                          nil];
    NSLog(@"run command: %@",commandToRun);
    [task setArguments: arguments];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    
    [task launch];
    
    NSData *data;
    data = [file readDataToEndOfFile];
    
    NSString *output;
    output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    return output;
}


+ (void)lockScreen
{
    int screenSaverDelayUserSetting = 0;
    
    screenSaverDelayUserSetting = [self readScreensaveDelay];
    
    if (screenSaverDelayUserSetting != 0) {
        // if the delay isn't already 0, temporarily set it to 0 so the screen locks immediately.
        [self setScreensaverDelay:0];
        [self touchSecurityPreferences];
    }
    
    io_registry_entry_t r = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/IOResources/IODisplayWrangler");
    if (r) {
        IORegistryEntrySetCFProperty(r, CFSTR("IORequestIdle"), sleep ? kCFBooleanTrue : kCFBooleanFalse);
        IOObjectRelease(r);
    }
    
    if (screenSaverDelayUserSetting != 0) {
        [self setScreensaverDelay:screenSaverDelayUserSetting];
        [self launchAndQuitSecurityPreferences];
    }
}

+ (void)touchSecurityPreferences
{
    // necessary for screen saver setting changes to take effect on file-vault-enabled systems
    // NOTE: this *only* works when going from non-zero settings of askForPasswordDelay to zero.
    
    NSAppleScript *kickSecurityPreferencesScript = [[NSAppleScript alloc] initWithSource: @"tell application \"System Events\" to tell security preferences to set require password to wake to true"];
    [kickSecurityPreferencesScript executeAndReturnError:nil];
}

+ (void)launchAndQuitSecurityPreferences
{
    // necessary for screen saver setting changes to take effect on file-vault-enabled systems when going from a askForPasswordDelay setting of zero to a non-zero setting
    NSAppleScript *kickSecurityPreferencesScript = [[NSAppleScript alloc] initWithSource:
                                                    @"tell application \"System Preferences\"\n"
                                                    @"     tell anchor \"General\" of pane \"com.apple.preference.security\" to reveal\n"
                                                    @"     activate\n"
                                                    @"end tell\n"
                                                    @"delay 0\n"
                                                    @"tell application \"System Preferences\" to quit"];
    [kickSecurityPreferencesScript executeAndReturnError:nil];
}

+ (int)readScreensaveDelay
{
    NSArray *arguments = @[@"read",@"com.apple.screensaver",@"askForPasswordDelay"];
    
    NSTask *readDelayTask = [[NSTask alloc] init];
    [readDelayTask setArguments:arguments];
    [readDelayTask setLaunchPath: @"/usr/bin/defaults"];
    
    NSPipe *pipe = [NSPipe pipe];
    [readDelayTask setStandardOutput:pipe];
    NSFileHandle *file = [pipe fileHandleForReading];
    [readDelayTask launch];
    NSData *resultData = [file readDataToEndOfFile];
    NSString *resultString = [[NSString alloc] initWithData:resultData encoding:NSUTF8StringEncoding];
    return resultString.intValue;
}

+ (void)setScreensaverDelay:(int)delay
{
    NSArray *arguments = @[@"write",@"com.apple.screensaver",@"askForPasswordDelay", [NSString stringWithFormat:@"%i", delay]];
    NSTask *resetDelayTask = [[NSTask alloc] init];
    [resetDelayTask setArguments:arguments];
    [resetDelayTask setLaunchPath: @"/usr/bin/defaults"];
    [resetDelayTask launch];
}
@end
