//
//  BluetoothService.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "bgValue.h"

@interface Storage : NSObject

+ (instancetype)instance;

-(BOOL) addBGValue:(int)value valueModule:(NSString*)value_module valueData:(NSData*)value_data valueTime:(unsigned long)seconds rawValue:(int)raw_value rawSource:(NSString*)raw_source rawData:(NSData*)raw_data;
-(NSArray*) bgValuesFrom:(NSTimeInterval)from to:(NSTimeInterval)to;
-(NSTimeInterval) lastBGValue;
-(bgValue*) lastBgBefore:(NSTimeInterval)before;
-(bgRawValue*) lastRawBgBefore:(NSTimeInterval)before;

-(BOOL) addBatteryValue:(int)volt raw:(int)raw source:(NSString*)source device:(Class)device;
-(NSArray*) batteryValuesFrom:(NSTimeInterval)from to:(NSTimeInterval)to;

-(BOOL) log:(NSString*)message from:(NSString*)from;

-(NSMutableDictionary*) deviceData;
-(void) saveDeviceData:(NSDictionary*)device;

-(NSString*) getSelectedDeviceClass;
-(void) setSelectedDeviceClass:(NSString*)deviceClass;
-(NSString*) getSelectedCalibrationClass;
-(void) setSelectedCalibrationClass:(NSString*)calibrationClass;
-(NSString*) getSelectedDisplayUnit;
-(void) setSelectedDisplayUnit:(NSString*)unit;

-(NSMutableDictionary*)getAlarmData;
-(void)setAlarmData:(NSMutableDictionary*)alarmData;
-(NSMutableDictionary*)getBGData;
-(void)setBGData:(NSMutableDictionary*)alarmData;
-(NSMutableDictionary*)getGeneralData;
-(void)setGeneralData:(NSMutableDictionary*)general;
-(NSMutableDictionary*)getNSData;
-(void)setNSData:(NSMutableDictionary*)ns;
-(void)setAgree:(BOOL)agreed;
-(BOOL)agreed;
@end

