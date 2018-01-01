//
//  BluetoothService.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "Configuration.h"
#import "Calibration.h"
#import "bgRawValue.h"
#import "bgValue.h"
#import "Storage.h"

@implementation Calibration

-(instancetype) init {
    self = [super init];
    if (self) {
        [self registerForRaw];
    }
    return self;
}

-(void) registerForRaw {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(recieved:) name:kDeviceRawValueNotification object:nil];
}

-(void) recieved:(NSNotification*)notification {
    bgRawValue* raw = [notification object];
    if(raw==nil)
        [[Storage instance] log:@"recieved nil Value" from:@"Calibration"];
    else {
        double rawV = raw.rawValue;

        if(rawV < 30)
            rawV=30;

        [[Storage instance] log:[NSString stringWithFormat:@"recieved limitter Value %f",rawV] from:@"Calibration"];
        [[Storage instance] addBGValue:rawV
                           valueModule:@"Calibration"
                             valueData:nil
                             valueTime:([[NSDate date] timeIntervalSince1970])
                              rawValue:raw.rawValue rawSource:[raw rawSource] rawData:[raw rawData]];
        bgValue* before = [[Storage instance] lastBgBefore:[[NSDate date] timeIntervalSince1970]];
        double delta = NAN;
        if([before timestamp] + (10*60) > [[NSDate date] timeIntervalSince1970]) {
            delta = rawV-before.value;
            delta /= ([[NSDate date] timeIntervalSince1970] - before.timestamp)/60.0;
        }
        bgValue* bgV = [[bgValue alloc] initWith:rawV from:[raw rawSource] at:[[NSDate date] timeIntervalSince1970] delta:delta raw:raw];
        [[NSNotificationCenter defaultCenter] postNotificationName:kCalibrationBGValue object:bgV];
    }
}

+(NSString*) configurationName {
    return NSLocalizedString(@"Default Calibration",@"NoCalibration: default Headline");
}

+(NSString*) configurationDescription {
    return NSLocalizedString(@"Does not apply any Calibration to the recieved Value.",@"NoCalibration: description");
}

+(UIViewController*) configurationViewController {
    return nil;
}

-(void)unregister {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
