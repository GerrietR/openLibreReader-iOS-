//
//  BluetoothService.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "Configurable.h"
#import "DeviceStatus.h"


#define kDeviceRawValueNotification @"DEVICE_RAW_BG_VALUE"
#define kDeviceStatusNotification @"DEVICE_STATUS"
#define kDeviceRequestStatusNotification @"DEVICE_REQUEST_STATUS"
#define kDeviceBatteryValueNotification @"DEVICE_BATTERY_VALUE"

@interface Device : Configurable

@property (strong) DeviceStatus* lastDeviceStatus;

-(BOOL) needsConnection;
-(void) reload;

-(void)unregister;

-(int) batteryMaxValue;
-(int) batteryMinValue;
-(int) batteryFullValue;
-(int) batteryLowValue;

-(void) log:(NSString*)message;

-(NSString*) settingsSequeIdentifier;

-(NSArray*) getRequestedDeviceUUIDs;
@end

