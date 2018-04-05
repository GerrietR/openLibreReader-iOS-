//
//  calibrationValue.h
//  openLibreReader
//
//  Created by Gerriet Reents on 06.01.18.
//  Copyright © 2018 Sandra Keßler. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface calibrationValue : NSObject
@property (readonly) int value;
@property (readonly) int referenceValue;
@property (readonly) NSTimeInterval timestamp;
@property (strong,readonly) NSString* module;

-(instancetype) initWith:(int)value reference:(int)reference from:(NSString*)module at:(NSTimeInterval)timestamp;
@end
