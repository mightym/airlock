//
//  ALAppDelegate.m
//  airlockios
//
//  Created by Mark Wirblich on 13.11.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALAppDelegate.h"
#import <CoreBluetooth/CoreBluetooth.h>


@interface ALAppDelegate () <CBPeripheralManagerDelegate> {}

@property(nonatomic, strong) CBPeripheralManager *peripheral;
@property(nonatomic, strong) CBMutableCharacteristic *characteristic;
@property(nonatomic, strong) CBMutableService *service;

@end

@implementation ALAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    [self setupBluetooth];
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark -
- (void)setupBluetooth
{
    self.peripheral = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
}

- (void)enableService
{
    NSLog(@"enableService");
    if (self.service) {
        [self.peripheral removeService:self.service];
    }

    self.service = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:@"1E960C29-5247-44E7-BEEE-A91FBC21454F"]
                                                  primary:YES];
    
    self.characteristic = [[CBMutableCharacteristic alloc]
                           initWithType:[CBUUID UUIDWithString:@"2ABFE74D-52E2-47FD-A574-B7FECB3EE8AF"]
                           properties:CBCharacteristicPropertyNotify
                           value:nil
                           permissions:0];
    
    // Assign the characteristic.
    self.service.characteristics = [NSArray arrayWithObject:self.characteristic];
    
    // Add the service to the peripheral manager.
    [self.peripheral addService:self.service];
}

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    NSLog(@"peripheralManagerDidUpdateState %ld", peripheral.state);
    if (peripheral.state == CBPeripheralManagerStatePoweredOn) {
        [self enableService];
    }
}

- (void)startAdvertising
{
    NSLog(@"startAdvertising");
    if (self.peripheral.isAdvertising) [self.peripheral stopAdvertising];

    NSDictionary *advertisment = @{
                                   CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:@"1E960C29-5247-44E7-BEEE-A91FBC21454F"]],
                                   CBAdvertisementDataLocalNameKey: @"AirlockPeripheral"
                                   };
    [self.peripheral startAdvertising:advertisment];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral
            didAddService:(CBService *)service
                    error:(NSError *)error {
    [self startAdvertising];
}

@end
