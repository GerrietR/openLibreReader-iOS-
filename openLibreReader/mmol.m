//
//  BluetoothService.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "mmol.h"

@implementation mmol

+(NSString*) configurationName {
    return @"mmol/l";
}

+(NSString*) configurationDescription {
    return NSLocalizedString(@"use this if your values are measured in mmol, typically between 3.3 and 9.5",@"Description for mmol unit");
}

+(UIViewController*) configurationViewController {
    return nil;
}

@end
