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
    if (self.deviceService != nil) [self.deviceService stopScanning];
}

#pragma mark -

- (void) scanForDevices
{
    self.deviceService = [[ALDeviceService alloc] init];
    self.deviceService.delegate = self;
    [self.deviceService scanForNearbyDevices];

    [[self.deviceService devices] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        ALDiscoveredDevice* device = (ALDiscoveredDevice*)obj;
        if (device.deviceName != nil && ![device.deviceName isEqualToString:@""]) {
            [self.listOfFoundDevices addObject:device];
        }
    }];

    [self.tableView reloadData];
}


#pragma mark - ALDeviceServiceDelegate

- (void)airlockDeviceService:(ALDeviceService *)service didFoundDevice:(ALDiscoveredDevice *)device
{
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

- (void)airlockDeviceService:(ALDeviceService *)service didUpdateDevice:(ALDiscoveredDevice *)device
{
    if (![self.listOfFoundDevices containsObject:device]) {
        [self.listOfFoundDevices addObject:device];
    }
    [self.tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:[self.listOfFoundDevices indexOfObject:device]]
                              columnIndexes:[NSIndexSet indexSetWithIndex:0]];
}

#pragma mark - NSTableViewDatasource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
{
    return MAX([self.listOfFoundDevices count], 1);
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if ([self.listOfFoundDevices count] > 0) {
        ALDiscoveredDevice* device = (ALDiscoveredDevice*)[self.listOfFoundDevices objectAtIndex:row];
        return [NSString stringWithString:device.description];
    } else {
        return @"searching for devices...";
    }
}

#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    if (self.tableView.selectedRowIndexes.count > 0 && self.listOfFoundDevices.count > 0) {
        ALDiscoveredDevice* selectedDevice = (ALDiscoveredDevice*)[self.listOfFoundDevices objectAtIndex:self.tableView.selectedRowIndexes.firstIndex];
        self.setupWindowController.selectedDevice = selectedDevice;
        [self.setupWindowController.continueButton setEnabled:YES];
    } else {
        self.setupWindowController.selectedDevice = nil;
        [self.setupWindowController.continueButton setEnabled:NO];
    }
}



@end
