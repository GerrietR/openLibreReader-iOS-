//
//  demo.m
//  openLibreReader
//
//  Created by Gerriet Reents on 17.12.17.
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "demo.h"
#import "Storage.h"
#import "Configuration.h"
#import "bgValue.h"
#import "AppDelegate.h"
#import "demoDeviceViewController.h"

@interface demoDevice ()
@property long lastSGV;
@property long direction;
@property NSTimer *timer; // retain?

- (void)_timerFired:(NSTimer *)timer;
@end

@implementation demoDevice

- (instancetype)init {
    self = [super init];
    if (self) {
        [self reload];
        _lastSGV=111;
        _direction=1;
    }
    return self;
}

-(void) willSuspend:(NSNotification*)notification {
}

-(void) didActivate:(NSNotification*)notification {
    [self reload];
}

-(void) reload {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestStatus:) name:kDeviceRequestStatusNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willSuspend:) name:kAppWillSuspend object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didActivate:) name:kAppDidActivate object:nil];
    
    DeviceStatus* ds = [[DeviceStatus alloc] init];
    ds.status = DEVICE_CONNECTED;
    ds.statusText = [NSString stringWithFormat:NSLocalizedString(@"connected",@"demo: connected")];
    ds.device = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:ds];
    self.lastDeviceStatus = ds;
    _lastSGV = 111;
    
    NSString* rawSource = @"demo-0";
    int bgValue = 0;
    NSData* rawData = [NSData dataWithBytes: &bgValue length: sizeof(bgValue)];
    
    bgRawValue* rawValue = [[bgRawValue alloc] initWith:(((double)_lastSGV)/1.0) withData:rawData from:rawSource];
    [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceRawValueNotification object:rawValue];

    if (!_timer) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:30.0f
                                                  target:self
                                                selector:@selector(_timerFired:)
                                                userInfo:nil
                                                 repeats:YES];
    }
}

-(void) requestStatus:(NSNotification*)notification {
    if(self.lastDeviceStatus) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:self.lastDeviceStatus];
    }
}

-(BOOL) needsConnection {
    return NO;
}

-(void)unregister
{
    // TODO: Right place?
    if ([_timer isValid]) {
        [_timer invalidate];
    }
    _timer = nil;

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}



- (void)_timerFired:(NSTimer *)timer {
    if (_lastSGV>250)
    {
        _direction=-1;
    }
    else if (_lastSGV<50)
    {
        _direction=1;
    }
    _lastSGV+=_direction;
    
    NSString* rawSource = @"demo-0";
    int bgValue = 0;
    NSData* rawData = [NSData dataWithBytes: &bgValue length: sizeof(bgValue)];
    
    bgRawValue* rawValue = [[bgRawValue alloc] initWith:(((double)_lastSGV)/1.0) withData:rawData from:rawSource];
    [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceRawValueNotification object:rawValue];
}

#pragma mark -
#pragma mark configuration

+(NSString*) configurationName {
    return @"Demo device";
}

+(NSString*) configurationDescription {
    return NSLocalizedString(@"Values are generated randomly",@"demoDevice: Description");
}

+(UIViewController*) configurationViewController {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    
    UIViewController* vc = [storyboard instantiateViewControllerWithIdentifier:@"DemoDeviceViewController"];
    return vc;
}

#pragma mark -
#pragma mark device Functions
-(int) batteryMaxValue {
    return 1024;
}

-(int) batteryMinValue {
    return 750;
}

-(int) batteryFullValue {
    return 925;
}

-(int) batteryLowValue {
    return 850;
}

-(NSString*) settingsSequeIdentifier {
    return @"demoDeviceSettings";
}
@end


