//
//  BluetoothService.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Device.h"
#import "Calibration.h"

#define kConfigurationReloadNotification @"RELOAD_CONFIGURATION"

@interface Configuration : NSObject
+(instancetype) instance;

+(NSMutableDictionary*) defaultAlarmData;
+(NSMutableDictionary*) defaultBGData;
+(NSMutableDictionary*) defaultGeneralData;
+(NSMutableDictionary*) defaultNSData;

@property (strong) Device* device;
@property (strong) Calibration* calibration;

#pragma mark - limits
-(void) setLowerBGLimit:(int)bg;
-(int) lowerBGLimit;
-(void) setUpperBGLimit:(int)bg;
-(int) upperBGLimit;
-(void) setLowBGLimit:(int)bg;
-(int) lowBGLimit;
-(void) setHighBGLimit:(int)bg;
-(int) highBGLimit;

#pragma mark - configuration
-(void) resetConfiguration:(NSNotification*)notification;

-(NSArray*) neededConfigurationSteps;
-(void) saveNeededSteps:(NSDictionary*)configData;
-(NSUInteger) optionsForStep:(int)step;
-(Class) option:(int)option forStep:(int)step;
-(NSString*) optionHeadline:(int)option forStep:(int)step;
-(NSString*) optionText:(int)option forStep:(int)step;

-(void) reloadNSUploadService;

#pragma mark - alarm data
-(int) alarmNoDataMinutes;//0 for disable
-(void) setAlarmNoDataMinutes:(int)minutes;
-(BOOL) alarmNoDataRepeats;
-(void) setAlarmNoDataRepeats:(BOOL)repeats;
-(int) alarmLowBG;
-(void) setAlarmLowBG:(int)low;
-(BOOL) alarmLowBGRepeats;
-(void) setAlarmLowBGRepeats:(BOOL)repeats;
-(int) alarmHighBG;
-(void) setAlarmHighBG:(int)low;
-(BOOL) alarmHighBGRepeats;
-(void) setAlarmHighBGRepeats:(BOOL)repeats;

-(void) setAlarmsDisabled:(BOOL)disabled;
-(void) setAlarmsDisabledUntil:(NSDate*)disabledUntil;
-(NSDate*) alarmsDisabled;

#pragma mark - display
-(NSString*) displayUnit;
-(double) valueInDisplayUnit:(double)value;
-(NSString*) valueWithUnit:(double)value;
-(NSString*) valueWithoutUnit:(double)value;
-(int) fromValue:(double)value;

#pragma mark - device
-(void) setKeepRunning:(BOOL)running;
-(BOOL) keepRunning;
-(void) setOverrideMute:(BOOL)noMute;
-(BOOL) overrideMute;
-(NSArray*) getRequestedDeviceUUIDs;

#pragma mark - nightscout
-(BOOL) nsUpload;
-(BOOL) setNsUpload:(BOOL)enabled;
-(NSString*) nightscoutUploadURL;
-(void) setNightscoutUploadURL:(NSString*)url;
-(NSString*) nightscoutUploadHash;
-(void) setNightscoutUploadHash:(NSString*)url;


@end

void registerDevice(Class deviceClass);
void registerCalibration(Class calibrationClass);
