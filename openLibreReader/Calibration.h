//
//  BluetoothService.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "Configurable.h"

#define kCalibrationBGValue @"CALIBRATION_BG_VALUE"

@interface Calibration : Configurable
-(void) registerForRaw;
-(void)unregister;

-(NSString*) settingsSequeIdentifier;
@end

