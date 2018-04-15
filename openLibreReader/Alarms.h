//
//  BluetoothService.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <UserNotifications/Usernotifications.h>
#import <AVFoundation/AVFoundation.h>

typedef enum {
    kAlarmRunning,
    kAlarmEnabled,
    kAlarmDisabled,
} AlarmState;

@interface Alarms : NSObject<UNUserNotificationCenterDelegate, AVAudioPlayerDelegate>
+(instancetype) instance;
- (void) notifyTermination;

-(AlarmState) getState;
-(void) cancelDelivered;
-(void) disable:(NSTimeInterval)interval;

@end

