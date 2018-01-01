//
//  SimpleLinearRegressionCalibration.m
//  openLibreReader
//
//  Created by Gerriet Reents on 30.12.17.
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SimpleLinearRegressionCalibration.h"
#import "bgRawValue.h"
#import "bgValue.h"
#import "Storage.h"
#import "Device.h"

@interface SimpleLinearRegressionCalibration ()
@end

@implementation SimpleLinearRegressionCalibration

-(double) getSlope {
    NSMutableDictionary* data = [[Storage instance] deviceData];
    NSString* slope = [data objectForKey:@"SimpleLinearRegressionSlope"];
    if(!slope)
    {
        return 1.08;
    }
    else
    {
      return [slope doubleValue];
    }
}

-(double) getIntercept {
    NSMutableDictionary* data = [[Storage instance] deviceData];
    NSString* intercept = [data objectForKey:@"SimpleLinearRegressionIntercept"];
    if(!intercept)
    {
        return 19.86;
    }
    else
    {
      return [intercept doubleValue];
    }
}

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
        [[Storage instance] log:@"recieved nil Value" from:@"SimpleLinearRegressionCalibration"];
    else {
        double rawV = raw.rawValue;
        [[Storage instance] log:[NSString stringWithFormat:@"recieved Value %f",(rawV)] from:@"SimpleLinearRegressionCalibration"];
        rawV = [self getIntercept] + [self getSlope] * rawV;
        [[Storage instance] addBGValue:rawV
                           valueModule:@"SimpleLinearRegressionCalibration"
                             valueData:nil
                             valueTime:([[NSDate date] timeIntervalSince1970])
                              rawValue:[raw rawValue] rawSource:[raw rawSource] rawData:[raw rawData]];
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
    return NSLocalizedString(@"Simple Linear Regression Calibration",@"SimpleLinearRegressionCalibration: headline");
}

+(NSString*) configurationDescription {
    return NSLocalizedString(@"A simple linear regression model is used for calibration",@"SimpleLinearRegressionCalibration: description");
}

+(UIViewController*) configurationViewController {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    
    UIViewController* vc = [storyboard instantiateViewControllerWithIdentifier:@"SimpleLinearRegressionViewController"];
    return vc;
}

-(void)unregister {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(NSString*) settingsSequeIdentifier {
    return @"SimpleLinearRegressionCalibrationSettings";
}

@end
