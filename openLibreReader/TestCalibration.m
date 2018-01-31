//
//  BluetoothService.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "TestCalibration.h"
#import "bgRawValue.h"
#import "bgValue.h"
#import "Storage.h"
#import "Device.h"

@interface TestCalibration ()
@end

@implementation TestCalibration

-(instancetype) init {
    self = [super init];
    if (self) {
    }
    return self;
}

-(void) registerForRaw {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(recieved:) name:kDeviceRawValueNotification object:nil];
}

-(void) recieved:(NSNotification*)notification {
    bgRawValue* raw = [notification object];
    if(raw==nil)
        [[Storage instance] log:@"recieved nil Value" from:@"TestCalibration"];
    else {
        double rawV = raw.rawValue;

        [[Storage instance] log:[NSString stringWithFormat:@"recieved Value %f",(rawV)] from:@"TestCalibration"];
        double fac = random();
        fac /= (double)RAND_MAX;
        fac*=300.0;
        fac-=150;
        rawV = (rawV)+fac;
        if(rawV<30.0)rawV=30.0;
        if(rawV>375.0)rawV=375.0;
        [[Storage instance] addBGValue:10+(rawV)
                           valueModule:@"RandomCalibration"
                             valueData:nil
                             valueTime:([[NSDate date] timeIntervalSince1970])
                             rawSource:[raw rawSource]
                               rawData:[raw rawData]];
        
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
    return NSLocalizedString(@"Random Calibration",@"RandomCalibration: headline");
}

+(NSString*) configurationDescription {
    return NSLocalizedString(@"The correct (without any calibration applied) raw value is saved to database, but the display value is randomized to test varoius functions.",@"RandomCalibration: description");
}

-(void)unregister {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
