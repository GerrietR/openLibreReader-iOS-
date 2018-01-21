//
//  SimpleLinearRegressionCalibration.h
//  openLibreReader
//
//  Created by Gerriet Reents on 30.12.17.
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Calibration.h"

@interface SimpleLinearRegressionCalibration : Calibration

-(void) startCalibration:(float)bg delay:(int)delay;

-(bool) isCalibrating:(float*)progress;

-(unsigned long) getNumberOfCalibration;

-(void) cancelCalibration;

-(void) setSlope: (double)value;

-(void) setIntercept: (double)value;

-(void) linearRegression: (double*)slope intercept:(double*)intercept;

-(void) deleteCalibration:(NSTimeInterval)timestamp;

@end
