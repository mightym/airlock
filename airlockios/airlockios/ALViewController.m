//
//  ALViewController.m
//  airlockios
//
//  Created by Mark Wirblich on 13.11.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALViewController.h"
#import "ALBeaconListener.h"

@interface ALViewController ()
@property (nonatomic, strong) ALBeaconListener* beaconListener;
@end

@implementation ALViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated
{
    NSUUID* beaconUUID = [[NSUUID alloc] initWithUUIDString:@"B9407F30-F5F8-466E-AFF9-25556B57FE6D"];
    self.beaconListener = [[ALBeaconListener alloc] initWithUUID:beaconUUID
                                                           major:40526
                                                           minor:7099];
    [self.beaconListener start];
}

@end
