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

-(bool) isCalibrating:(float*)progress remaining:(NSTimeInterval*)remaining;

-(float) getCurrentBG;

-(unsigned long) getNumberOfCalibration;

-(NSArray*) getCalibrations;

-(void) cancelCalibration;

-(void) setSlope: (double)value;

-(void) setIntercept: (double)value;

-(void) setCalibrationsStartDate: (NSDate*)startDate;

-(double) getSlope;

-(double) getIntercept;

-(NSDate*) getCalibrationsStartDate;

-(void) linearRegression: (double*)slope intercept:(double*)intercept ;

-(double) qualityOfLinearRegression: (double)slope intercept:(double)intercept;

-(void) deleteCalibration:(NSTimeInterval)timestamp;

@end
