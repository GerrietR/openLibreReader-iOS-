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
#import "calibrationValue.h"
#import "Storage.h"
#import "Device.h"

static SimpleLinearRegressionCalibration* __instance;

@interface SimpleLinearRegressionCalibration () {
    bool    isCalibrating;
    float   referenceValue;
    NSDate*  compareAtTimestamp;
    NSDate*  started;
}
@end

@implementation SimpleLinearRegressionCalibration

+(instancetype) instance {
    if(__instance==nil)
        __instance = [[SimpleLinearRegressionCalibration alloc] init];
    return __instance;
}

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

-(void) setSlope: (double)value {
    NSMutableDictionary* data = [[Storage instance] deviceData];
    NSString* slope = [NSString stringWithFormat:@"%.2f",value];
    NSLog(@"got %@ as new value for slope",slope);
    [data setObject:slope forKey:@"SimpleLinearRegressionSlope"];
    [[Storage instance] saveDeviceData:data];
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

-(void) setIntercept: (double)value {
    NSMutableDictionary* data = [[Storage instance] deviceData];
    NSString* intercept = [NSString stringWithFormat:@"%.2f",value];
    NSLog(@"got %@ as new value for intercept",intercept);
    [data setObject:intercept forKey:@"SimpleLinearRegressionIntercept"];
    [[Storage instance] saveDeviceData:data];
}

-(instancetype) init {
    self = [super init];
    if (self) {
        isCalibrating = false;
        referenceValue = 0.0;
        compareAtTimestamp = nil;
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
        NSDate* now = [[NSDate date] init];
        [[Storage instance] addBGValue:rawV
                           valueModule:@"SimpleLinearRegressionCalibration"
                             valueData:nil
                             valueTime:[now timeIntervalSince1970]
                             rawSource:[raw rawSource] rawData:[raw rawData]];
        bgValue* before = [[Storage instance] lastBgBefore:[[NSDate date] timeIntervalSince1970]];
        double delta = NAN;
        if([before timestamp] + (10*60) > [[NSDate date] timeIntervalSince1970]) {
            delta = rawV-before.value;
            double minutes = ([[NSDate date] timeIntervalSince1970] - before.timestamp)/60.0;
            delta /= minutes;
        }
        bgValue* bgV = [[bgValue alloc] initWith:rawV from:[raw rawSource] at:[[NSDate date] timeIntervalSince1970] delta:delta raw:raw];
        [[NSNotificationCenter defaultCenter] postNotificationName:kCalibrationBGValue object:bgV];
        if (isCalibrating)
        {
            if ([now compare:compareAtTimestamp] == NSOrderedDescending)
            {
                // todo: cancel because of old readings
                [[Storage instance]  addCalibration: [raw rawValue] reference:referenceValue valueTime:[now timeIntervalSince1970] module:@"SimpleLinearRegressionCalibration"];
                // todo: calculate new regression parameters
                isCalibrating = false;
            }
        }
    }
}

-(void) startCalibration:(float)bg delay:(int)delay {
    if (!isCalibrating)
    {
        NSDate* delayTill = [[NSDate date] initWithTimeIntervalSinceNow:delay*60];
        compareAtTimestamp = delayTill;
        started = [NSDate date];
        isCalibrating = true;
        referenceValue = bg;
    }
    else
    {
         [[Storage instance] log:@"already calibrating!" from:@"SimpleLinearRegressionCalibration"];
    }
}

-(bool) isCalibrating:(float*) progress
{
    if (isCalibrating)
    {
        if (fabs([started timeIntervalSince1970] - [compareAtTimestamp timeIntervalSince1970]) < 1.0 )
        {
            *progress=1;
        } else {
            *progress = ([[NSDate date] timeIntervalSince1970] - [started timeIntervalSince1970]) /
                        ([compareAtTimestamp timeIntervalSince1970] - [started timeIntervalSince1970]);
        }
        return true;
    }
    else
    {
        *progress = 0.0;
        return false;
    }
}

-(float) getCurrentBG;
{
    if (isCalibrating)
    {
        return referenceValue;
    }
    else
    {
        return -1.0;
    }
}

-(unsigned long) getNumberOfCalibration{
    NSArray* values = [[Storage instance]  calibrationFrom:[[NSDate distantPast] timeIntervalSince1970]  to:[[NSDate date] timeIntervalSince1970]];
    return [values count];
};

-(void) cancelCalibration
{
    isCalibrating = false;
}

- (void)linearRegressionInternal:(double*)slope intercept:(double*)intercept xvalues:(NSArray *)xvalues yvalues:(NSArray *)yvalues {

    // based on https://stackoverflow.com/questions/10863732/linear-regression-in-objective-c
    NSUInteger n = [xvalues count];
    double ax, ay, sX, sY, ssX, ssY, ssXY, avgX, avgY, radius;
    
    sX = sY = ssX = ssY = ssXY = 0;
    // Sum of squares X, Y & X*Y
    for (int i = 0; i < n; i++)
    {
        ax = [xvalues[i] doubleValue];
        ay = [yvalues[i] doubleValue];
        sX += ax;
        sY += ay;
        ssX += ax * ax;
        ssY += ay * ay;
        ssXY += ax * ay;
    }
    
    avgX = sX / n;
    avgY = sY / n;
    radius = hypot(avgX, avgY);
    ssX = ssX - n * (avgX * avgX);
    ssY = ssY - n * (avgY * avgY);
    ssXY = ssXY - n * avgX * avgY;
    
    // Best fit of line y_i = a + b * x_i
    double b = ssXY / ssX;
    double a = (avgY - b * avgX);
//    double theta = atan2(1, b);
    
    
    // Correlationcoefficent gives the quality of the estimate: 1 = perfect to 0 = no fit
    double corCoeff = (ssXY * ssXY) / (ssX * ssY);
    
    NSLog(@"n: %lu, a: %f --- b: %f --- cor: %f   --- avgX: %f -- avgY: %f --- ssX: %f - ssY: %f - ssXY: %f", (unsigned long)n, a, b, corCoeff, avgX, avgY, ssX, ssY, ssXY);

    if (intercept) *intercept=a;
    if (slope) *slope=b;
}

- (void) linearRegression: (double*)slope intercept:(double*)intercept
{
    NSArray* values = [[Storage instance]  calibrationFrom:[[NSDate distantPast] timeIntervalSince1970]  to:[[NSDate date] timeIntervalSince1970]];
    NSMutableArray *xValues = [NSMutableArray array];
    NSMutableArray *yValues = [NSMutableArray array];
    calibrationValue* calibration;
    for (calibration in values)
    {
        [xValues addObject:[NSNumber numberWithInt:calibration.value]];
        [yValues addObject:[NSNumber numberWithInt:calibration.referenceValue]];
    }
    [self linearRegressionInternal:slope intercept:intercept xvalues:xValues yvalues:yValues];
    
}

-(void) deleteCalibration:(NSTimeInterval)timestamp{
    [[Storage instance]  deleteCalibration:timestamp module:@"SimpleLinearRegressionCalibration"];
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
