//
//  BluetoothService.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "Alarms.h"
#import "Calibration.h"
#import "Configuration.h"
#import "AppDelegate.h"
#import "Storage.h"

typedef enum {
    kNoData,
    kLow,
    kHigh
} AlarmType;

Alarms* instance = nil;

@interface Alarms ()
    @property (strong) AVAudioPlayer* player;
@end

@implementation Alarms

+(instancetype) instance {
    return instance;
}
-(instancetype) init {
    if(instance)
        return instance;
    self = [super init];
    if(self)
    {
        instance = self;
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newBG:) name:kCalibrationBGValue object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceStatus:) name:kDeviceStatusNotification object:nil];
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        center.delegate = self;

        NSError* error = nil;
        _player = [[AVAudioPlayer alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"default_error_shorter" withExtension:@"caf"] error:&error];
        if(error)
            NSLog(@"eeror: %@",[error debugDescription]);
        _player.delegate =self;
        _player.volume = 1.0;
        _player.numberOfLoops = 1;

        [center requestAuthorizationWithOptions:(UNAuthorizationOptionBadge | UNAuthorizationOptionSound | UNAuthorizationOptionAlert)
                              completionHandler:^(BOOL granted, NSError * _Nullable error) {
                                  if (error) {
                                      [[Storage instance] log:[NSString stringWithFormat:@"error getting allowance for notifications: %@",[error debugDescription]] from:@"Alarms"];
                                  } else {
                                      UNNotificationAction* snoozehalfAction = [UNNotificationAction
                                                                                actionWithIdentifier:@"SNOOZE_ALARMS_0"
                                                                                title:NSLocalizedString(@"Snooze for 30 minutes",@"notification.30")
                                                                                options:UNNotificationActionOptionNone];

                                      UNNotificationAction* snoozeoneAction = [UNNotificationAction
                                                                                actionWithIdentifier:@"SNOOZE_ALARMS_1"
                                                                                title:NSLocalizedString(@"Snooze for 1h",@"notification.1")
                                                                                options:UNNotificationActionOptionNone];

                                      UNNotificationAction* snoozetwoAction = [UNNotificationAction
                                                                                actionWithIdentifier:@"SNOOZE_ALARMS_2"
                                                                                title:NSLocalizedString(@"Snooze for 2h",@"notification.2")
                                                                                options:UNNotificationActionOptionNone];

                                      UNNotificationAction* stopAction = [UNNotificationAction
                                                                          actionWithIdentifier:@"DISABLE_ALARMS"
                                                                          title:NSLocalizedString(@"Disable Alarms",@"notification.disable")
                                                                          options:UNNotificationActionOptionDestructive];
                                      UNNotificationAction* appAction = [UNNotificationAction
                                                                         actionWithIdentifier:@"TO_APP"
                                                                         title:NSLocalizedString(@"Open opneLibreReader",@"notification.app")
                                                                         options:UNNotificationActionOptionForeground];
                                      UNNotificationCategory* noDataCategory = [UNNotificationCategory
                                                                                categoryWithIdentifier:@"noData"
                                                                                actions:@[snoozehalfAction, snoozeoneAction, snoozetwoAction, appAction, stopAction]
                                                                                intentIdentifiers:@[]
                                                                                options:UNNotificationCategoryOptionCustomDismissAction];
                                      [center setNotificationCategories:[NSSet setWithObjects:noDataCategory, nil]];

                                      if(![[Configuration instance] alarmsDisabled] || [[NSDate date] compare:[[Configuration instance] alarmsDisabled]] ==  NSOrderedDescending) {
                                          [self scheduleMessage:[[Configuration instance] alarmNoDataMinutes] identifier:kNoData repeats:[[Configuration instance] alarmNoDataRepeats] urgent:NO];
                                      }
                                  }
                              }];

    }
    return self;
}

-(void) scheduleMessage:(int) minutes identifier:(AlarmType)type repeats:(BOOL)repeat urgent:(BOOL)urgent{
    UNMutableNotificationContent *objNotificationContent = [[UNMutableNotificationContent alloc] init];
    NSString* identifier;
    switch(type) {
        case kNoData:
            [self removeMessage:kNoData];
            objNotificationContent.title = NSLocalizedString(@"no Data!",@"notification.noDataTitle");
            objNotificationContent.body = [NSString stringWithFormat:NSLocalizedString(@"no Data for %d minutes",@"notification.noDataBody"),minutes];
            //objNotificationContent.sound = [UNNotificationSound soundNamed:@"default_error_shorter.caf"];
            objNotificationContent.badge = @(1);

            objNotificationContent.categoryIdentifier=@"noData";
            identifier=@"noData";
            break;
        case kLow:
            objNotificationContent.title = NSLocalizedString(@"Low Value!",@"notification.lowTitle");
            objNotificationContent.body = [NSString stringWithFormat:NSLocalizedString(@"Attention, value is below %@!",@"notification.lowBody"),
                                           [[Configuration instance] valueWithUnit:[[Configuration instance] alarmLowBG]]];
            //objNotificationContent.sound = [UNNotificationSound soundNamed:@"default_error_shorter.caf"];
            objNotificationContent.badge = @(1);

            objNotificationContent.categoryIdentifier=@"noData";
            identifier=@"low";
            break;
        case kHigh:
            objNotificationContent.title = NSLocalizedString(@"High Value!",@"notification.highTitle");
            objNotificationContent.body = [NSString stringWithFormat:NSLocalizedString(@"Attention, value is above %@!",@"notification.highBody"),
                                           [[Configuration instance] valueWithUnit:[[Configuration instance] alarmHighBG]]];
            //objNotificationContent.sound = [UNNotificationSound soundNamed:@"default_error_shorter.caf"];
            objNotificationContent.badge = @(1);

            objNotificationContent.categoryIdentifier=@"noData";
            identifier=@"high";
            break;
    }
    UNTimeIntervalNotificationTrigger *trigger = nil;
    if(minutes>0) {
        trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:(minutes*60) repeats:repeat];
    } else if(repeat) {
        trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:(60) repeats:repeat];
    }
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier
                                                                          content:objNotificationContent trigger:trigger];

    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];

    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
        if (error) {
            [[Storage instance] log:[NSString stringWithFormat:@"failed to make notification: %@",[error debugDescription]] from:@"Alarms"];
        }/* else {
            [[Storage instance] log:[NSString stringWithFormat:@"made noti: %@ at %@",identifier,trigger] from:@"Alarms"];
        }*/
    }];
    if(urgent) {
        request = [UNNotificationRequest requestWithIdentifier:identifier content:objNotificationContent trigger:nil];
        [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
            if (error) {
                [[Storage instance] log:[NSString stringWithFormat:@"failed to make notification: %@",[error debugDescription]] from:@"Alarms"];
            }/* else {
              [[Storage instance] log:[NSString stringWithFormat:@"made noti: %@ at %@",identifier,trigger] from:@"Alarms"];
              }*/
        }];
   }

}

-(void) removeMessage:(AlarmType)type {    NSArray* types;
    switch(type) {
        case kNoData:
            types = @[@"noData"];
            break;
        case kHigh:
            types = @[@"high"];
            break;
        case kLow:
            types = @[@"low"];
            break;
    }
    //NSLog(@"removing type: %@",types);
    [[UNUserNotificationCenter currentNotificationCenter] removePendingNotificationRequestsWithIdentifiers:types];
}
-(void) newBG:(NSNotification*)notification {
    if(![[Configuration instance] alarmsDisabled] || [[NSDate date] compare:[[Configuration instance] alarmsDisabled]] ==  NSOrderedDescending) {
        bgValue* bg = [notification object];
        if([[Configuration instance] alarmLowBG]!=0 && bg.value <= [[Configuration instance] alarmLowBG]) {
            [[UNUserNotificationCenter currentNotificationCenter] getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> * _Nonnull requests) {
                BOOL found = NO;
                for(UNNotificationRequest* request in requests) {
                    if([request.identifier isEqualToString:@"low"]) found = YES;
                }
                if(!found) {
                    [self scheduleMessage:0 identifier:kLow repeats:[[Configuration instance] alarmLowBGRepeats] urgent:YES];
                }
            }];
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionDuckOthers error:nil];
            [[AVAudioSession sharedInstance] setActive:YES error:nil];
            [_player play];
        } else {
            [self removeMessage:kLow];
        }
        if([[Configuration instance] alarmHighBG]!=0 && bg.value >= [[Configuration instance] alarmHighBG]) {
            [[UNUserNotificationCenter currentNotificationCenter] getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> * _Nonnull requests) {
                BOOL found = NO;
                for(UNNotificationRequest* request in requests) {
                    if([request.identifier isEqualToString:@"high"]) found = YES;
                }
                if(!found) {
                    [self scheduleMessage:0 identifier:kHigh repeats:[[Configuration instance] alarmHighBGRepeats] urgent:YES];
                }
            }];
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionDuckOthers error:nil];
            [[AVAudioSession sharedInstance] setActive:YES error:nil];
            [_player play];
        } else {
            [self removeMessage:kHigh];

        }
    } else {
        [self removeMessage:kLow];
        [self removeMessage:kHigh];
    }
}

-(void)deviceStatus:(NSNotification*)notification {
    DeviceStatus* status = notification.object;
    if(status.status == DEVICE_OK) {
        [self removeMessage:kNoData];
    }
    [[UNUserNotificationCenter currentNotificationCenter] getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> * _Nonnull requests) {
        BOOL found = NO;
        for(UNNotificationRequest* request in requests) {
            if([request.identifier isEqualToString:@"noData"]) found = YES;
        }
        if(!found) {
            if(![[Configuration instance] alarmsDisabled] || [[NSDate date] compare:[[Configuration instance] alarmsDisabled]] ==  NSOrderedDescending) {
                    [self scheduleMessage:[[Configuration instance] alarmNoDataMinutes] identifier:kNoData repeats:[[Configuration instance] alarmNoDataRepeats] urgent:NO];
            }
        }
    }];
}

-(void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler{
    if([[Configuration instance] overrideMute]) {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionDuckOthers error:nil];
        [[AVAudioSession sharedInstance] setActive:YES error:nil];
        [_player play];
        /*if ([AVAudioSession sharedInstance].otherAudioPlaying) {
            // you can check and play only if there is no other audio playing
            // maybe use another category, or enable mixing or duck option
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionDuckOthers error:nil];
        } else {
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        }
        [[AVAudioSession sharedInstance] setActive:YES error:nil];

        if([_player play]) {
            NSLog(@"startung playint");
        } else {
            NSLog(@"notplaying");
        }*/

        completionHandler(UNAuthorizationOptionAlert | UNAuthorizationOptionBadge);
    } else {
        completionHandler(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge);
    }
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
}

-(void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(nonnull UNNotificationResponse *)response withCompletionHandler:(nonnull void (^)(void))completionHandler{
    if([_player isPlaying]) {
        [_player stop];
        [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    }
    if([response.actionIdentifier isEqualToString:@"SNOOZE_ALARMS_0"]) {
        [[Configuration instance] setAlarmsDisabledUntil:[NSDate dateWithTimeIntervalSinceNow:30*60]];
        [self removeMessage:kNoData];
        [self removeMessage:kLow];
        [self removeMessage:kHigh];
    } else if([response.actionIdentifier isEqualToString:@"SNOOZE_ALARMS_1"]) {
        [[Configuration instance] setAlarmsDisabledUntil:[NSDate dateWithTimeIntervalSinceNow:60*60]];
        [self removeMessage:kNoData];
        [self removeMessage:kLow];
        [self removeMessage:kHigh];
    } else if([response.actionIdentifier isEqualToString:@"SNOOZE_ALARMS_2"]) {
        [[Configuration instance] setAlarmsDisabledUntil:[NSDate dateWithTimeIntervalSinceNow:120*60]];
        [self removeMessage:kNoData];
        [self removeMessage:kLow];
        [self removeMessage:kHigh];
    } else if([response.actionIdentifier isEqualToString:@"DISABLE_ALARMS"]) {
        [[Configuration instance] setAlarmsDisabled:YES];
        [self removeMessage:kNoData];
        [self removeMessage:kLow];
        [self removeMessage:kHigh];
    } else if([response.actionIdentifier isEqualToString:@"TO_APP"]
               || [response.actionIdentifier isEqualToString:UNNotificationDefaultActionIdentifier]
               || [response.actionIdentifier isEqualToString:UNNotificationDismissActionIdentifier]) {
        [self removeMessage:kNoData];
        [self removeMessage:kLow];
        [self removeMessage:kHigh];
    }
    [UIApplication sharedApplication].applicationIconBadgeNumber--;
    completionHandler();
}

- (void) notifyTermination {
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionDuckOthers error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    [_player play];

    UNMutableNotificationContent *objNotificationContent = [[UNMutableNotificationContent alloc] init];
    NSString* identifier;
    objNotificationContent.title = NSLocalizedString(@"App Terminated!",@"notification.terminated");
    objNotificationContent.body = NSLocalizedString(@"Attention, app has been terminated!",@"notification.terminatedBody");
    objNotificationContent.sound = [UNNotificationSound soundNamed:@"default_error_shorter.caf"];
    objNotificationContent.badge = @(1);

    objNotificationContent.categoryIdentifier=@"terminated";
    identifier=@"terminated";

    UNTimeIntervalNotificationTrigger *trigger = nil;
    trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:(60) repeats:YES];
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier
                                                                          content:objNotificationContent trigger:trigger];

    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];

    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
        if (error) {
            [[Storage instance] log:[NSString stringWithFormat:@"failed to make notification: %@",[error debugDescription]] from:@"Alarms"];
        }
    }];
    request = [UNNotificationRequest requestWithIdentifier:identifier content:objNotificationContent trigger:nil];
    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
        if (error) {
            [[Storage instance] log:[NSString stringWithFormat:@"failed to make notification: %@",[error debugDescription]] from:@"Alarms"];
        }

    }];
}

-(AlarmState) getState
{
    __block BOOL hasRunning = NO;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [[UNUserNotificationCenter currentNotificationCenter] getDeliveredNotificationsWithCompletionHandler:^(NSArray<UNNotification *> * _Nonnull notifications) {
        hasRunning = [notifications count]>0;
        dispatch_semaphore_signal(sema);

    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);

    if(hasRunning)
        return kAlarmRunning;

    if([[Configuration instance] alarmsDisabled] && [[NSDate date] compare:[[Configuration instance] alarmsDisabled]] ==  NSOrderedAscending) {
        return kAlarmDisabled;
    }

    return kAlarmEnabled;
}

-(void) cancelDelivered {
    [[UNUserNotificationCenter currentNotificationCenter] removeAllDeliveredNotifications];
    [[UNUserNotificationCenter currentNotificationCenter] removeAllPendingNotificationRequests];
    if([_player isPlaying]) {
        [_player stop];
        [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    }
}

-(void) disable:(NSTimeInterval) interval {
    if([_player isPlaying]) {
        [_player stop];
        [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    }
    if(interval==-1) {
        [[UNUserNotificationCenter currentNotificationCenter] removeAllPendingNotificationRequests];
        [[Configuration instance] setAlarmsDisabled:YES];
    } else if(interval==0) {
        [[Configuration instance] setAlarmsDisabled:NO];
    } else {
        [[UNUserNotificationCenter currentNotificationCenter] removeAllPendingNotificationRequests];
        [[Configuration instance] setAlarmsDisabledUntil:[NSDate dateWithTimeIntervalSinceNow:interval]];
    }
}

@end



