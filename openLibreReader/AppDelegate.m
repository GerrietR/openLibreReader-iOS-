//
//  AppDelegate.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "AppDelegate.h"
#import "Configuration.h"
#import <UserNotifications/UserNotifications.h>

#import "Calibration.h"
#import "TestCalibration.h"
#import "SimpleLinearRegressionCalibration.h"

#import "blueReader.h"
#import "nightscout.h"
#import "limitter.h"

#import "BluetoothService.h"
#import "Alarms.h"

#import <MMWormhole/MMWormhole.h>
#import "batteryValue.h"
#import "bgValue.h"
#import "Storage.h"
#import "HomeViewController.h"

@interface AppDelegate ()
@property (strong) BluetoothService* bluetoothService;
@property (strong) Alarms* alarms;
@property (nonatomic,strong) MMWormhole* wormhole;
@property (nonatomic, strong)   NSMutableDictionary* wormholeData;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.

    if(launchOptions)
        NSLog(@"launchies: %@",[launchOptions debugDescription]);

    _alarms = [[Alarms alloc] init];
    registerCalibration([Calibration class]);
    registerCalibration([TestCalibration class]);
    registerCalibration([SimpleLinearRegressionCalibration class]);

    registerDevice([blueReader class]);
    registerDevice([nightscout class]);
    registerDevice([limitter class]);

    _bluetoothService = [[BluetoothService alloc] init];
    [[NSNotificationCenter defaultCenter] postNotificationName:kConfigurationReloadNotification object:nil];
    self.wormhole = [[MMWormhole alloc] initWithApplicationGroupIdentifier:@"group.bluetoolz.openbluereader"
                                                         optionalDirectory:@"wormhole"];
    _wormholeData = [NSMutableDictionary new];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(recieved:) name:kCalibrationBGValue object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceStatus:) name:kDeviceStatusNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(recievedBattery:) name:kDeviceBatteryValueNotification object:nil];

    return YES;
}
-(void)recievedBattery:(NSNotification*)notification {
    batteryValue* data = [notification object];

    if(data.raw < [[Configuration instance].device batteryLowValue]) {
        [_wormholeData setObject:@"battery-red" forKey:@"battery"];
    } else if(data.raw < [[Configuration instance].device batteryFullValue]) {
        [_wormholeData setObject:@"battery-yellow" forKey:@"battery"];
    } else {
        [_wormholeData setObject:@"battery-green" forKey:@"battery"];
    }
    [self makeWormholeData];
}
-(void)deviceStatus:(NSNotification*)notification
{
    DeviceStatus* ds = [notification object];
    if(ds) {
        [_wormholeData setObject:ds.statusText forKey:@"status"];
        [self makeWormholeData];
    }
}
-(void) makeWormholeData {
    NSData* archive = [NSKeyedArchiver archivedDataWithRootObject:_wormholeData];
    [_wormholeData setObject:[[Storage instance] getSelectedDisplayUnit] forKey:@"unit"];
    [_wormholeData setObject:[NSNumber numberWithInt:[[Configuration instance] lowerBGLimit]] forKey:@"lowerBGLimit"];
    [_wormholeData setObject:[NSNumber numberWithInt:[[Configuration instance] upperBGLimit]] forKey:@"upperBGLimit"];
    [_wormholeData setObject:[NSNumber numberWithInt:[[Configuration instance] lowBGLimit]] forKey:@"lowBGLimit"];
    [_wormholeData setObject:[NSNumber numberWithInt:[[Configuration instance] highBGLimit]] forKey:@"highBGLimit"];

    [self.wormhole passMessageObject:archive
                          identifier:@"currentData"];
}
-(void)recieved:(NSNotification*)notification {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterNoStyle;
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    dateFormatter.timeZone = [NSTimeZone defaultTimeZone];

    [_wormholeData setObject:[dateFormatter stringFromDate: [NSDate dateWithTimeIntervalSince1970:((bgValue*)notification.object).timestamp]] forKey:@"lastTime"];
    //[_wormholeData setObject:_drift.text forKey:@"drift"];
    //[_wormholeData setObject:_direction.text forKey:@"direction"];

    NSArray* data = [[Storage instance] bgValuesFrom:[[NSDate date]timeIntervalSince1970]-(8*60*60) to:[[NSDate date]timeIntervalSince1970]];
    unsigned long count = [data count];
    Configuration* c = [Configuration instance];

    if(count>0) {
        bgValue* last = ((bgValue*)[data lastObject]);
        [_wormholeData setObject:[[Configuration instance] valueWithoutUnit:last.value] forKey:@"currentBG"];

        if(count>1) {
            bgValue* prelast = [data objectAtIndex:[data indexOfObject:last]-1];
            double t = [last timestamp]-[prelast timestamp];
            double d = [last value]-[prelast value];
            t/=60;
            double deltamin = d/t;
            if(t>15) {
                [_wormholeData setObject:@"---" forKey:@"drift"];
                [_wormholeData setObject:@"" forKey:@"direction"];
            } else {
                [_wormholeData setObject:[NSString stringWithFormat:@"%@ %@",(d>=0?@"+":@""),[c valueWithUnit:d]] forKey:@"drift"];
                [_wormholeData setObject:[HomeViewController slopeToArrowSymbol:deltamin] forKey:@"direction"];
            }
        } else {
            [_wormholeData setObject:[NSString stringWithFormat:@"-- %@",[c displayUnit]] forKey:@"drift"];
            [_wormholeData setObject:@"" forKey:@"direction"];
        }

    } else {
        [_wormholeData setObject:@"--" forKey:@"drift"];
        [_wormholeData setObject:@"" forKey:@"direction"];
    }

    NSMutableArray* valueArray = [NSMutableArray new];
    for(bgValue* value in [[Storage instance] bgValuesFrom:[[NSDate date]timeIntervalSince1970]-(8*60*60) to:[[NSDate date]timeIntervalSince1970]]) {
        [valueArray addObject:@{@"value":[NSNumber numberWithDouble:value.value],
                                @"timestamp":[NSNumber numberWithDouble:value.timestamp]
                                }];
    }
    [_wormholeData setObject:valueArray forKey:@"values"];
    if([_wormholeData count]) {
        NSData* archive = [NSKeyedArchiver archivedDataWithRootObject:_wormholeData];
        [self.wormhole passMessageObject:archive
                              identifier:@"currentData"];
    }
}
- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    [[NSNotificationCenter defaultCenter] postNotificationName:kAppWillSuspend object:nil];
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    [[NSNotificationCenter defaultCenter] postNotificationName:kAppDidActivate object:nil];

}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}
@end
