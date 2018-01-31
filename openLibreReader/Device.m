//
//  BluetoothService.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "Device.h"
#import "Storage.h"

@implementation Device

-(BOOL) needsConnection {
    @throw [NSException exceptionWithName:@"Instantiationexception"
                                   reason:@"not possible"
                                 userInfo:nil];
    return NO;
}
-(void) reload {
    @throw [NSException exceptionWithName:@"Instantiationexception"
                                   reason:@"not possible"
                                 userInfo:nil];
}

-(void)unregister {
    @throw [NSException exceptionWithName:@"Instantiationexception"
                                   reason:@"not possible"
                                 userInfo:nil];
}

-(int) batteryMaxValue {
    @throw [NSException exceptionWithName:@"Instantiationexception"
                                   reason:@"not possible"
                                 userInfo:nil];
    return 0;
}

-(int) batteryMinValue {
    @throw [NSException exceptionWithName:@"Instantiationexception"
                                   reason:@"not possible"
                                 userInfo:nil];
    return 0;
}

-(int) batteryFullValue {
    @throw [NSException exceptionWithName:@"Instantiationexception"
                                   reason:@"not possible"
                                 userInfo:nil];
    return 0;
}

-(int) batteryLowValue {
    @throw [NSException exceptionWithName:@"Instantiationexception"
                                   reason:@"not possible"
                                 userInfo:nil];
    return 0;
}

-(void) log:(NSString*)message {
    [[Storage instance] log:message from:[[self class] configurationName]];
}

-(NSString*) settingsSequeIdentifier {
    @throw [NSException exceptionWithName:@"Instantiationexception"
                                   reason:@"not possible"
                                 userInfo:nil];
    return nil;
}

-(NSArray*) getRequestedDeviceUUIDs {
    return nil;
}

@end
