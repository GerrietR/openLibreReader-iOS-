//
//  BluetoothService.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "blueReader.h"
#import "bgRawValue.h"
#import "Storage.h"
#import "batteryValue.h"
#import "DeviceViewController.h"
#import "Configuration.h"
#import "nightscout.h"
@interface blueReader ()
    @property (weak) CBCharacteristic* tx;
    @property (weak) CBCharacteristic* rx;
    @property BOOL shouldDisconnect;
@end

@implementation blueReader

- (instancetype)init {
    self = [super init];
    if (self) {
        [self reload];
        _shouldDisconnect = NO;
    }
    return self;
}

-(void) reload {
    [self log:@"reloading"];
    DeviceStatus* ds = [[DeviceStatus alloc] init];
    ds.status = DEVICE_DISCONNECTED;
    ds.statusText = [NSString stringWithFormat:NSLocalizedString(@"reloading",@"blueReader: reloading")];
    ds.device = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:ds];
    self.lastDeviceStatus = ds;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestStatus:) name:kDeviceRequestStatusNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceConnected:) name:BLUETOOTH_DEVICE_CONNECTED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(failed:) name:BLUETOOTH_DEVICE_FAILED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceDiscovered:) name:BLUETOOTH_DEVICE_DISCOVERED_SERVICE_CHARACTERISTICS object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(btStatus:) name:BLUETOOTH_STATUS object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceRestored:) name:BLUETOOTH_RESTORED_DEVICE object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(disconnected:) name:BLUETOOTH_DEVICE_DISCONNECTED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataRecieved:) name:BLUETOOTH_DEVICE_CHARACTERISTIC_CHANGED object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_REQUEST_STATE object:nil];
}

-(void)btStatus:(NSNotification*)notification {
    if([((BluetoothStatus*)[notification object]) state] == CBManagerStatePoweredOn) {
        NSDictionary* deviceData = [[Storage instance] deviceData];
        NSUUID* lastUsed = [[NSUUID alloc] initWithUUIDString:[deviceData objectForKey:@"blueReaderUUID"]];
        if(lastUsed) {
            [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_RESTORE_DEVICE object:lastUsed];
        } else {
            DeviceStatus* ds = [[DeviceStatus alloc] init];
            ds.status = NO_DEVICE;
            ds.statusText = [NSString stringWithFormat:NSLocalizedString(@"Not able to connect to %@",@"blueReader: Not able to connect to device"),[lastUsed UUIDString]];
            ds.device = nil;
            [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:ds];
            self.lastDeviceStatus = ds;
        }
    }
}

-(BOOL) needsConnection {
    NSDictionary* deviceData = [[Storage instance] deviceData];
    NSUUID* lastUsed = [[NSUUID alloc] initWithUUIDString:[deviceData objectForKey:@"blueReaderUUID"]];
    if(!lastUsed)
        return YES;
    if(self.device.state == CBPeripheralStateDisconnected)
        return YES;
    return NO;
}

-(void)unregister {
    [self log:@"unregistering"];
    if(self.device && self.tx && self.rx)
        [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_DISCONNECT_DEVICE object:self.device];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void) deviceRestored:(NSNotification*) notification {
    if([notification object]) {
        [self setDevice:[notification object]];
        DeviceStatus* ds = [[DeviceStatus alloc] init];
        ds.status = DEVICE_CONNECTING;
        ds.statusText = [NSString stringWithFormat:NSLocalizedString(@"Connecting to %@",@"blueReader: conencting to device"),[[notification object] name]];
        ds.device = nil;
        [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:ds];
        self.lastDeviceStatus = ds;
        [self log:[NSString stringWithFormat:@"connecting to %@",[notification object]]];
        [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_CONNECT_DEVICE object:[notification object]];
    } else {
        NSDictionary* deviceData = [[Storage instance] deviceData];
        NSUUID* lastUsed = [deviceData objectForKey:@"blueReaderUUID"];
        if(lastUsed) {
            [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_RESTORE_DEVICE object:lastUsed];
        }
    }
}

-(void) deviceConnected:(NSNotification*) notification {
    if([[((CBPeripheral*)[notification object]).name lowercaseString] rangeOfString:@"bluereader"].length!=0) {
        [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_STOP_SCAN object:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_DISCOVER_DEVICE object:[notification object]];
    }
}

-(void) disconnected:(NSNotification*) notification {
    if(![self device] || [[[self device] identifier] isEqual:[((CBPeripheral*)[notification object])identifier]]) {
        DeviceStatus* ds = [[DeviceStatus alloc] init];
        ds.status = DEVICE_DISCONNECTED;
        ds.statusText = [NSString stringWithFormat:NSLocalizedString(@"Disconnected from %@",@"blueReader: disconnect from device"),[[notification object] name]];
        ds.device = nil;
        [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:ds];
        self.lastDeviceStatus = ds;

        _tx = nil;
        _rx = nil;
        if(!_shouldDisconnect) {
            [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_CONNECT_DEVICE object:[self device]];
        } else {
            [self setDevice:nil];
        }
    }
    else {
        NSLog(@"not reconnecting to %@, waiting for %@",[notification object],[self device]);
    }
}
-(void) failed:(NSNotification*) notification {
    if(![self device] ||
       [[[self device] identifier] isEqual:[(CBPeripheral*)[[notification object] objectForKey:@"peripheral"] identifier]]) {
        DeviceStatus* ds = [[DeviceStatus alloc] init];
        ds.status = DEVICE_DISCONNECTED;
        ds.statusText = [NSString stringWithFormat:NSLocalizedString(@"failed connection to %@",@"blueReader: failed connecting to device"),[[[notification object] objectForKey:@"peripheral"] name]];
        ds.device = nil;
        [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:ds];
        self.lastDeviceStatus = ds;

        _tx = nil;
        _rx = nil;
        if(!_shouldDisconnect) {
            [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_START_SCAN object:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_CONNECT_DEVICE object:[self device]];
        } else {
            [self setDevice:nil];
        }
    }
    else {
        NSLog(@"failed connecting to %@, waiting for %@",[notification object],[self device]);
    }
}

-(void) deviceDiscovered:(NSNotification*) notification {
    if([[[notification object] objectForKey:@"peripheral"] isEqual:self.device]) {
        CBService* service = [[notification object] objectForKey:@"service"];
        if([service.UUID.UUIDString isEqualToString:BLUETOOTH_SERVICE_NORDIC_UART]) {
            for(CBCharacteristic* chara in service.characteristics) {
                if([chara.UUID.UUIDString isEqualToString:BLUETOOTH_SERVICE_NORDIC_UART_TX]) {
                    [self.device setNotifyValue:YES forCharacteristic:chara];
                    _tx = chara;
                } else if([chara.UUID.UUIDString isEqualToString:BLUETOOTH_SERVICE_NORDIC_UART_RX]) {
                    [self.device setNotifyValue:YES forCharacteristic:chara];
                    _rx = chara;
                }
            }
            if(_rx && _tx) {
                DeviceStatus* ds = [[DeviceStatus alloc] init];
                ds.status = DEVICE_CONNECTED;
                ds.statusText = [NSString stringWithFormat:NSLocalizedString(@"Connected to %@",@"blueReader: connected device"),[self.device name]];
                ds.device = self.device;
                [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:ds];
                self.lastDeviceStatus = ds;

                [self log:[NSString stringWithFormat:@"connected to %@",[self.device identifier]]];

                [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_SEND_DATA
                                                                    object:@{
                                                                             @"data":[@"l" dataUsingEncoding:NSUTF8StringEncoding],
                                                                             @"characteristic":_tx}];
            }
        }
    }
}

-(void) requestStatus:(NSNotification*)notification {
    if(self.lastDeviceStatus) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:self.lastDeviceStatus];
    }
}

-(void)dataRecieved:(NSNotification*)notification {
    if([[self device] isEqual:[notification.object objectForKey:@"peripheral"]]) {
        if([[[notification object] objectForKey:@"characteristic"] isEqual:_rx]) {
            NSData* data = ((CBCharacteristic*)[[notification object] objectForKey:@"characteristic"]).value;
            NSString* s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            [self log:[NSString stringWithFormat:@"recieved %@",s]];
            if([s hasPrefix:@"battery: "]) {
                NSArray* vals = [s componentsSeparatedByString:@" "];

                int volt = [[vals objectAtIndex:1] intValue];
                int raw = [[vals objectAtIndex:2] intValue];
                [[Storage instance] addBatteryValue:volt raw:raw source:@"blueReader-0" device:[self class]];

                batteryValue* bV = [[batteryValue alloc] initWith:volt raw:raw from:@"blueReader-0" class:[self class] at:[[NSDate date] timeIntervalSince1970]];
                [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceBatteryValueNotification
                                                                    object:bV];
                NSDictionary* deviceData = [[Storage instance] deviceData];
                int interval = [[deviceData objectForKey:@"interval"] intValue];
                if(interval==0) interval = 5;
                if([[NSDate date] timeIntervalSince1970]>=[[Storage instance] lastBGValue]+(60*interval)) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_SEND_DATA
                                                                        object:@{
                                                                             @"data":[@"l" dataUsingEncoding:NSUTF8StringEncoding],
                                                                             @"characteristic":_tx}];
                }
            } else if([[s lowercaseString] rangeOfString:@"not ready for"].length!=0) {
                [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(reset:) userInfo:nil repeats:NO];

            } else if([[s lowercaseString] rangeOfString:@"trans_failed"].length!=0) {
                DeviceStatus* ds = [[DeviceStatus alloc] init];
                ds.status = DEVICE_ERROR;
                ds.statusText = NSLocalizedString(@"No Sensor found",@"blueReader: no Sensor");
                ds.device = self.device;
                [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:ds];
                self.lastDeviceStatus = ds;
            } else {
                NSArray* words = [s componentsSeparatedByCharactersInSet :[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                NSString* trimmed = [words componentsJoinedByString:@""];
                if([blueReader isAllDigits:trimmed])
                {
                    int limitterValue = [[[s componentsSeparatedByString:@" "] objectAtIndex:0] doubleValue];
                    NSString* rawSource = @"blueReader-0";
                    NSData* rawData = [NSData dataWithBytes: &limitterValue length: sizeof(limitterValue)];

                    bgRawValue* rawValue = [[bgRawValue alloc] initWith:(((double)limitterValue)/1000.0) withData:rawData from:rawSource];
                    [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceRawValueNotification object:rawValue];
                    DeviceStatus* ds = [[DeviceStatus alloc] init];
                    ds.status = DEVICE_OK;
                    ds.statusText = NSLocalizedString(@"blueReader ok",@"blueReader: sensor ok");
                    ds.device = self.device;
                    [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:ds];
                    self.lastDeviceStatus = ds;

                }
            }
        }
    }
}

-(void) reset:(NSNotification*)notification {
    self.device = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_SEND_DATA
                                                        object:@{
                                                                 @"data":[@"y" dataUsingEncoding:NSUTF8StringEncoding],
                                                                 @"characteristic":_tx}];
}
+ (BOOL) isAllDigits:(NSString*)s {
    NSCharacterSet* nonNumbers = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    NSRange r = [s rangeOfCharacterFromSet: nonNumbers];
    return r.location == NSNotFound && s.length > 0;
}

#pragma mark -
#pragma mark configuration

+(NSString*) configurationName {
    return @"blueReader";
}

+(NSString*) configurationDescription {
    return NSLocalizedString(@"The blueReader is used to fetch values from the libre Tag.\nThe interval of fetches can be configured in 1 minute intervals.",@"blueReader: Description");
}

+(UIViewController*) configurationViewController {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];

    UIViewController* vc = [storyboard instantiateViewControllerWithIdentifier:@"DeviceSelectionTable"];
    ((DeviceViewController*)vc).deviceFilter = self;

    [[NSNotificationCenter defaultCenter] removeObserver:self name:DEVICEVIEW_CHOOSEN object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectedDevice:) name:DEVICEVIEW_CHOOSEN object:nil];
    return vc;
}

+(void) selectedDevice:(NSNotification*)notification {
    NSMutableDictionary* deviceData = [[Storage instance] deviceData];

    CBPeripheral* peripheral = [notification object];
    if(peripheral) {
        [deviceData setObject:[[peripheral identifier] UUIDString] forKey:@"blueReaderUUID"];
    } else {
        [deviceData removeObjectForKey:@"blueReaderUUID"];
    }
    [[Storage instance] saveDeviceData:deviceData];
    [[Configuration instance].device reload];
}

+(BOOL) compatibleService:(CBService*) service {
    if([[[service UUID] UUIDString] isEqualToString:BLUETOOTH_SERVICE_NORDIC_UART])
        return YES;
    return NO;
}

-(NSArray*) getRequestedDeviceUUIDs {
    return [NSArray arrayWithObjects:[CBUUID UUIDWithString:BLUETOOTH_SERVICE_NORDIC_UART], nil];
}

+(BOOL) compatibleName:(CBPeripheral*) peripheral {
    if([[peripheral.name lowercaseString] rangeOfString:@"bluereader"].length!=0)
        return YES;
    return NO;
}

#pragma mark -
#pragma mark device Functions
-(int) batteryMaxValue {
    return 1024;
}

-(int) batteryMinValue {
    return 700;
}

-(int) batteryFullValue {
    return 925;
}

-(int) batteryLowValue {
    return 850;
}

-(NSString*) settingsSequeIdentifier {
    return @"blueReaderDeviceSettings";
}
@end
