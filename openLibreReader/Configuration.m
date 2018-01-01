//
//  BluetoothService.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "Configuration.h"
#import "bgRawValue.h"
#import "Storage.h"
#import "Alarms.h"
#import "nightscout.h"

#import "mmol.h"
#import "mgdl.h"

typedef enum{
    ConfigDisplayUnit,
    ConfigDataSource,
    ConfigCalibration
} ConfigType;

static Configuration* __instance;

@interface Configuration ()
    @property (strong) NSMutableArray* devices;
    @property (strong) NSMutableArray* calibrations;
    @property (strong) nightscoutUploader* uploader;

-(void) addDevice:(Class)deviceClass;
-(void) addCalibration:(Class)calibrationClass;
@end

@implementation Configuration

-(instancetype) init {
    self = [super init];
    if (self) {
        if(__instance)
            assert("not possible");

        _devices = [NSMutableArray new];
        _calibrations = [NSMutableArray new];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadConfiguration:) name:kConfigurationReloadNotification object:nil];
    }
    return self;
}

+(instancetype) instance {
    if(__instance==nil)
        __instance = [[Configuration alloc] init];
    return __instance;
}

-(void)loadConfiguration:(NSNotification*)notification {
    if([[self neededConfigurationSteps] count] == 0) {
        Device* newDevice = [[NSClassFromString([[Storage instance] getSelectedDeviceClass]) alloc] init];
        if(newDevice) {
            if(_device) {
                [_device unregister];
            }
            _device = newDevice;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"CONFIGUARTION_DEVICE_CHANGED" object:_device];
        }
        if([[Storage instance] getSelectedCalibrationClass]) {
            Calibration* newCalibration = [[NSClassFromString([[Storage instance] getSelectedCalibrationClass]) alloc] init];
            if(newCalibration) {
                if(_calibration) {
                    [_calibration unregister];
                }
                _calibration = newCalibration;
                [[NSNotificationCenter defaultCenter] postNotificationName:@"CONFIGUARTION_CALIBRATION_CHANGED" object:_calibration];

            }
        } else {
            Calibration* newCalibration = [[Calibration alloc] init];
            if(_calibration) {
                [_calibration unregister];
            }
            _calibration = newCalibration;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"CONFIGUARTION_CALIBRATION_CHANGED" object:_calibration];
        }
        if([self keepRunning]) {
            [[UIDevice currentDevice] setProximityMonitoringEnabled:YES];
            [[UIApplication sharedApplication] setIdleTimerDisabled: YES];
        }
        _uploader = [[nightscoutUploader alloc] init];
    }
}

-(void) addDevice:(Class)deviceClass {
    [_devices addObject:deviceClass];
}

-(void) addCalibration:(Class)calibrationClass {
    [_calibrations addObject:calibrationClass];
}

-(void) reloadNSUploadService {
    [_uploader reload];
}

-(void) setLowerBGLimit:(int)bg {
    NSMutableDictionary* bgData = [[Storage instance] getBGData];
    [bgData setObject:[NSNumber numberWithInt:bg] forKey:@"lowerBGLimit"];
    [[Storage instance] setBGData:bgData];
}
-(int) lowerBGLimit {
    NSMutableDictionary* bgData = [[Storage instance] getBGData];
    return [[bgData objectForKey:@"lowerBGLimit"] intValue];
}
-(void) setUpperBGLimit:(int)bg {
    NSMutableDictionary* bgData = [[Storage instance] getBGData];
    [bgData setObject:[NSNumber numberWithInt:bg] forKey:@"upperBGLimit"];
    [[Storage instance] setBGData:bgData];
}
-(int) upperBGLimit {
    NSMutableDictionary* bgData = [[Storage instance] getBGData];
    return [[bgData objectForKey:@"upperBGLimit"] intValue];
}
-(void) setLowBGLimit:(int)bg {
    NSMutableDictionary* bgData = [[Storage instance] getBGData];
    [bgData setObject:[NSNumber numberWithInt:bg] forKey:@"lowBGLimit"];
    [[Storage instance] setBGData:bgData];
}
-(int) lowBGLimit {
    NSMutableDictionary* bgData = [[Storage instance] getBGData];
    return [[bgData objectForKey:@"lowBGLimit"] intValue];
}
-(void) setHighBGLimit:(int)bg {
    NSMutableDictionary* bgData = [[Storage instance] getBGData];
    [bgData setObject:[NSNumber numberWithInt:bg] forKey:@"highBGLimit"];
    [[Storage instance] setBGData:bgData];
}
-(int) highBGLimit {
    NSMutableDictionary* bgData = [[Storage instance] getBGData];
    return [[bgData objectForKey:@"highBGLimit"] intValue];
}

-(int) alarmNoDataMinutes {
    NSMutableDictionary* alarmData = [[Storage instance] getAlarmData];
    return [[alarmData objectForKey:@"noDataMinutes"] intValue];
}
-(void) setAlarmNoDataMinutes:(int)minutes {
    NSMutableDictionary* alarmData = [[Storage instance] getAlarmData];
    [alarmData setObject:[NSNumber numberWithInt:minutes] forKey:@"noDataMinutes"];
    [[Storage instance] setAlarmData:alarmData];
}
-(BOOL) alarmNoDataRepeats {
    NSMutableDictionary* alarmData = [[Storage instance] getAlarmData];
    return [[alarmData objectForKey:@"noDataRepeat"] boolValue];
}
-(void) setAlarmNoDataRepeats:(BOOL)repeats {
    NSMutableDictionary* alarmData = [[Storage instance] getAlarmData];
    [alarmData setObject:[NSNumber numberWithBool:repeats] forKey:@"noDataRepeat"];
    [[Storage instance] setAlarmData:alarmData];
}
-(int) alarmLowBG {
    NSMutableDictionary* alarmData = [[Storage instance] getAlarmData];
    return [[alarmData objectForKey:@"lowBG"] intValue];
}
-(void) setAlarmLowBG:(int)low {
    NSMutableDictionary* alarmData = [[Storage instance] getAlarmData];
    [alarmData setObject:[NSNumber numberWithInt:low] forKey:@"lowBG"];
    [[Storage instance] setAlarmData:alarmData];
}
-(BOOL) alarmLowBGRepeats {
    NSMutableDictionary* alarmData = [[Storage instance] getAlarmData];
    return [[alarmData objectForKey:@"lowRepeat"] boolValue];
}
-(void) setAlarmLowBGRepeats:(BOOL)repeats {
    NSMutableDictionary* alarmData = [[Storage instance] getAlarmData];
    [alarmData setObject:[NSNumber numberWithBool:repeats] forKey:@"lowRepeat"];
    [[Storage instance] setAlarmData:alarmData];
}
-(int) alarmHighBG {
    NSMutableDictionary* alarmData = [[Storage instance] getAlarmData];
    return [[alarmData objectForKey:@"highBG"] intValue];
}
-(void) setAlarmHighBG:(int)high {
    NSMutableDictionary* alarmData = [[Storage instance] getAlarmData];
    [alarmData setObject:[NSNumber numberWithInt:high] forKey:@"highBG"];
    [[Storage instance] setAlarmData:alarmData];
}
-(BOOL) alarmHighBGRepeats {
    NSMutableDictionary* alarmData = [[Storage instance] getAlarmData];
    return [[alarmData objectForKey:@"highRepeat"] boolValue];
}
-(void) setAlarmHighBGRepeats:(BOOL)repeats {
    NSMutableDictionary* alarmData = [[Storage instance] getAlarmData];
    [alarmData setObject:[NSNumber numberWithBool:repeats] forKey:@"highRepeat"];
    [[Storage instance] setAlarmData:alarmData];
}
-(void) setAlarmsDisabled:(BOOL)disabled {
    NSMutableDictionary* alarmData = [[Storage instance] getAlarmData];
    if(disabled)
        [alarmData setObject:[NSDate distantFuture] forKey:@"disabled"];
    else
        [alarmData removeObjectForKey:@"disabled"];
    [[Storage instance] setAlarmData:alarmData];
}
-(void) setAlarmsDisabledUntil:(NSDate*)disabledUntil; {
    NSMutableDictionary* alarmData = [[Storage instance] getAlarmData];
    [alarmData setObject:disabledUntil forKey:@"disabled"];
    [[Storage instance] setAlarmData:alarmData];
    NSLog(@"next alarm should be at: %@ == %@",[disabledUntil debugDescription],[self alarmsDisabled]);
}
-(NSDate*) alarmsDisabled {
    NSMutableDictionary* alarmData = [[Storage instance] getAlarmData];
    return [alarmData objectForKey:@"disabled"];
}
+(NSMutableDictionary*) defaultAlarmData
{
    NSDictionary* defaultData = @{
                                         @"highRepeat":[NSNumber numberWithBool:YES],
                                         @"highBG":[NSNumber numberWithInt:200],
                                         @"lowRepeat":[NSNumber numberWithBool:YES],
                                         @"lowBG":[NSNumber numberWithInt:70],
                                         @"noDataRepeat":[NSNumber numberWithBool:YES],
                                         @"noDataMinutes":[NSNumber numberWithInt:10],
                                         };
    return [NSMutableDictionary dictionaryWithDictionary:defaultData];

}
+(NSMutableDictionary*) defaultBGData {
    NSDictionary* defaultData = @{
                                  @"lowerBGLimit":[NSNumber numberWithInt:70],
                                  @"lowBGLimit":[NSNumber numberWithInt:60],
                                  @"highBGLimit":[NSNumber numberWithInt:200],
                                  @"upperBGLimit":[NSNumber numberWithInt:170],
                                  };
    return [NSMutableDictionary dictionaryWithDictionary:defaultData];
}
+(NSMutableDictionary*) defaultGeneralData {
    NSDictionary* defaultData = @{
                                  @"keepRunning":[NSNumber numberWithBool:YES],
                                  @"overrideMute":[NSNumber numberWithBool:NO],
                                  };
    return [NSMutableDictionary dictionaryWithDictionary:defaultData];
}
+(NSMutableDictionary*) defaultNSData {
    NSDictionary* defaultData = @{
                                  @"uploadEnabled":[NSNumber numberWithBool:NO],
                                  };
    return [NSMutableDictionary dictionaryWithDictionary:defaultData];
}
-(NSArray*) neededConfigurationSteps {
    NSString* device = [[Storage instance] getSelectedDeviceClass];
    NSString* calibration = [[Storage instance] getSelectedCalibrationClass];
    NSString* unit = [[Storage instance] getSelectedDisplayUnit];

    NSMutableArray* steps = [NSMutableArray new];
    if(unit == nil || [@[[mmol class],[mgdl class]] containsObject:NSClassFromString(unit)] == NO) {
        [steps addObject:[NSNumber numberWithInteger:ConfigDisplayUnit]];
    }

    if(device == nil || NSClassFromString(device)==nil || [_devices containsObject:NSClassFromString(device)] == NO) {
        [steps addObject:[NSNumber numberWithInteger:ConfigDataSource]];
    }

    if(calibration == nil || NSClassFromString(calibration)==nil || [_calibrations containsObject:NSClassFromString(calibration)] == NO) {
        [steps addObject:[NSNumber numberWithInteger:ConfigCalibration]];
    }
    return steps;
}

-(void) saveNeededSteps:(NSDictionary*)configData {
    for(NSNumber* element in [configData allKeys]) {
        Class value = [configData objectForKey:element];
        NSString* className = nil;
        switch([element intValue]) {
            case ConfigDataSource:
                className = NSStringFromClass(value);
                [[Storage instance] setSelectedDeviceClass:className];
                break;
            case ConfigCalibration:
                className = NSStringFromClass(value);
                [[Storage instance] setSelectedCalibrationClass:className];
                break;
            case ConfigDisplayUnit:
                className = NSStringFromClass(value);
                [[Storage instance] setSelectedDisplayUnit:className];
                break;
        }
        [[Storage instance] log:[NSString stringWithFormat:@"saved for option %d value: %@",[element intValue],className] from:@"Configuration"];
    }
    [self loadConfiguration:nil];
}

-(NSUInteger) optionsForStep:(int)step {
    switch(step) {
        case ConfigDataSource:
            return [_devices count];
        case ConfigCalibration:
            return [_calibrations count];
        case ConfigDisplayUnit:
            return 2;
    }
    return 1;//need a placeholder
}

-(Class) option:(int)option forStep:(int)step {
    switch(step) {
        case ConfigDataSource:
            return [_devices objectAtIndex:option];
        case ConfigCalibration:
            return [_calibrations objectAtIndex:option];
        case ConfigDisplayUnit:
            return [@[[mmol class],[mgdl class]] objectAtIndex:option];
    }
    return nil;
}

-(NSString*) optionHeadline:(int)option forStep:(int)step {
    switch(step) {
        case ConfigDataSource:
            return [[_devices objectAtIndex:option] configurationName];
        case ConfigCalibration:
            return [[_calibrations objectAtIndex:option] configurationName];
        case ConfigDisplayUnit:
            return [[@[[mmol class],[mgdl class]] objectAtIndex:option] configurationName];
    }
    return nil;
}

-(NSString*) optionText:(int)option forStep:(int)step {
    switch(step) {
        case ConfigDataSource:
            return [[_devices objectAtIndex:option] configurationDescription];
        case ConfigCalibration:
            return [[_calibrations objectAtIndex:option] configurationDescription];
        case ConfigDisplayUnit:
            return [[@[[mmol class],[mgdl class]] objectAtIndex:option] configurationDescription];
    }
    return nil;
}

-(void) resetConfiguration:(NSNotification*)notificatio {
    [[Storage instance] setSelectedDisplayUnit:nil];
    [[Storage instance] setSelectedCalibrationClass:nil];
    [[Storage instance] setSelectedDeviceClass:nil];
    [[Storage instance] saveDeviceData:nil];
    if(_device) {
        [_device unregister];
        _device = nil;
    }
    if(_calibration) {
        [_calibration unregister];
        _calibration = nil;
    }
}

/**
 * adopted from https://github.com/dabear/FloatingGlucose/blob/b5c001504f84501a81c52c465dae8fa210bab655/FloatingGlucose/Classes/Utils/GlucoseMath.cs#L11
 */
+(double) asMmol:(double) mgdl {
    return round((mgdl / 18.01559)*10.0) / 10.0;
}

+(double)asMgdl:(double)mmol {
    return round(mmol * 18.01559);//no decimals for mgdl values
}

-(NSString*) displayUnit {
    NSString* unit = [[Storage instance] getSelectedDisplayUnit];
    if([[unit lowercaseString] rangeOfString:@"mmol"].length!=0) {
        return @"mmol";
    }
    return @"mg/dl";
}

-(double) valueInDisplayUnit:(double)value {
    NSString* unit = [[Storage instance] getSelectedDisplayUnit];
    if([[unit lowercaseString] rangeOfString:@"mmol"].length!=0) {
        return [Configuration asMmol:value];
    }
    return value;
}

-(NSString*) valueWithUnit:(double)value {
    NSString* unit = [[Storage instance] getSelectedDisplayUnit];
    if([[unit lowercaseString] rangeOfString:@"mmol"].length!=0) {
        return [NSString stringWithFormat:@"%.1f mmol",[Configuration asMmol:value]];
    }
    return [NSString stringWithFormat:@"%.0f mg/dl",value];
}

-(NSString*) valueWithoutUnit:(double)value {
    NSString* unit = [[Storage instance] getSelectedDisplayUnit];
    if([[unit lowercaseString] rangeOfString:@"mmol"].length!=0) {
        return [NSString stringWithFormat:@"%.1f",[Configuration asMmol:value]];
    }
    return [NSString stringWithFormat:@"%.0f",value];
}

-(int) fromValue:(double)value {
    NSString* unit = [[Storage instance] getSelectedDisplayUnit];
    if([[unit lowercaseString] rangeOfString:@"mmol"].length!=0) {
        return [Configuration asMgdl:value];
    }
    return value;
}

-(void) setKeepRunning:(BOOL)running {
    NSMutableDictionary* general = [[Storage instance] getGeneralData];
    [general setObject:[NSNumber numberWithBool:running] forKey:@"keepRunning"];
    [[Storage instance] setGeneralData:general];
    if(running) {
        [[UIDevice currentDevice] setProximityMonitoringEnabled:YES];
        [[UIApplication sharedApplication] setIdleTimerDisabled: YES];
    } else {
        [[UIDevice currentDevice] setProximityMonitoringEnabled:NO];
        [[UIApplication sharedApplication] setIdleTimerDisabled: NO];
    }
}

-(BOOL) keepRunning {
    NSMutableDictionary* general = [[Storage instance] getGeneralData];
    return [[general objectForKey:@"keepRunning"] boolValue];
}

-(void) setOverrideMute:(BOOL)noMute {
    NSMutableDictionary* general = [[Storage instance] getGeneralData];
    [general setObject:[NSNumber numberWithBool:noMute] forKey:@"overrideMute"];
    [[Storage instance] setGeneralData:general];
}

-(BOOL) overrideMute {
    NSMutableDictionary* general = [[Storage instance] getGeneralData];
    return [[general objectForKey:@"overrideMute"] boolValue];
}

-(BOOL) nsUpload {
    NSMutableDictionary* general = [[Storage instance] getNSData];
    return [[general objectForKey:@"uploadEnabled"] boolValue];
}
-(BOOL) setNsUpload:(BOOL)enabled {
    if([[[Storage instance] getSelectedDeviceClass] isEqual:[nightscout class]])
        enabled = NO;
    NSMutableDictionary* general = [[Storage instance] getNSData];
    [general setObject:[NSNumber numberWithBool:enabled] forKey:@"uploadEnabled"];
    [[Storage instance] setNSData:general];
    return enabled;
}
-(NSString*) nightscoutUploadURL{
    NSMutableDictionary* general = [[Storage instance] getNSData];
    return [general objectForKey:@"uploadURL"];
}
-(void) setNightscoutUploadURL:(NSString*)url {
    NSMutableDictionary* general = [[Storage instance] getNSData];
    [general setObject:url forKey:@"uploadURL"];
    [[Storage instance] setNSData:general];
}
-(NSString*) nightscoutUploadHash {
    NSMutableDictionary* general = [[Storage instance] getNSData];
    return [general objectForKey:@"uploadHash"];
}
-(void) setNightscoutUploadHash:(NSString*)url {
    NSMutableDictionary* general = [[Storage instance] getNSData];
    [general setObject:url forKey:@"uploadHash"];
    [[Storage instance] setNSData:general];
}
@end

void registerDevice(Class deviceClass) {
    Configuration* configuration = [Configuration instance];
    [configuration addDevice:deviceClass];
}

void registerCalibration(Class calibrationClass) {
    Configuration* configuration = [Configuration instance];
    [configuration addCalibration:calibrationClass];
}
