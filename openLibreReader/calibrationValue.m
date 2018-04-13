//
//  calibrationValue.m
//  openLibreReader
//
//  Created by Gerriet Reents on 06.01.18.
//  Copyright © 2018 Sandra Keßler. All rights reserved.
//

#import "calibrationValue.h"

@implementation calibrationValue

-(instancetype) initWith:(int)value reference:(int)reference from:(NSString*)module at:(NSTimeInterval)timestamp {
    self = [super init];
    if (self) {
        _value= value;
        _referenceValue=reference;
        _module = module;
        _timestamp = timestamp;
    }
    return self;
}

@end

