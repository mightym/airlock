//
//  ALSetupStep3ViewController.m
//  airlockmac
//
//  Created by Tobias Liebig on 17.12.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALSetupStep3ViewController.h"
#import "ALDiscoveredDevice.h"

@interface ALSetupStep3ViewController ()
@property (nonatomic, strong) NSMutableArray *listOfFoundDevices;
@property (nonatomic, strong) IBOutlet NSTableView *tableView;
@property (nonatomic, strong) ALDeviceService *deviceService;
@end

@implementation ALSetupStep3ViewController

- (void)awakeFromNib
{
    self.listOfFoundDevices = [NSMutableArray array];
}

- (void)start {
    [self scanForDevices];
}

- (void)stop {
    if (self.deviceService == nil) [self.deviceService stopScanning];
}

#pragma mark -

- (void) scanForDevices
{
    self.deviceService = [[ALDeviceService alloc] init];
    self.deviceService.delegate = self;
    [self.deviceService scanForNearbyDevices];

    [[self.deviceService devices] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [self.listOfFoundDevices addObject:obj];
    }];

    [self.tableView reloadData];
}


#pragma mark - ALDeviceServiceDelegate

- (void)airlockDeviceService:(ALDeviceService *)service didFoundDevice:(ALDiscoveredDevice *)device
{
    [self.listOfFoundDevices addObject:device];
    [self.tableView reloadData];
}

- (void)airlockDeviceService:(ALDeviceService *)service didRemoveDeviceWithIdentifier:(NSUUID *)identifier
{
    ALDiscoveredDevice* deviceToRemove = nil;
    for (ALDiscoveredDevice* device in self.listOfFoundDevices) {
        if ([device.identifier isEqualTo:identifier]) {
            deviceToRemove = device;
            break;
        }
    }
    if (deviceToRemove != nil) {
        [self.listOfFoundDevices removeObject:deviceToRemove];
        [self.tableView reloadData];
    }
}

#pragma mark - NSTableViewDatasource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
{
    return [self.listOfFoundDevices count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    return [[(ALDiscoveredDevice*)[self.listOfFoundDevices objectAtIndex:row] identifier] UUIDString];
}

#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    NSLog(@"tableViewSelectionDidChange");
}

@end
