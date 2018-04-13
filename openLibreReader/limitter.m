//
//  BluetoothService.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "limitter.h"
#import "bgRawValue.h"
#import "Storage.h"
#import "batteryValue.h"
#import "DeviceViewController.h"
#import "Configuration.h"
#import "nightscout.h"
@interface limitter ()
    @property (weak) CBCharacteristic* rx;
    @property BOOL shouldDisconnect;
@end

@implementation limitter

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
    ds.statusText = [NSString stringWithFormat:NSLocalizedString(@"reloading",@"limitter: reloading")];
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
        NSUUID* lastUsed = [[NSUUID alloc] initWithUUIDString:[deviceData objectForKey:@"limitterUUID"]];
        if(lastUsed) {
            [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_RESTORE_DEVICE object:lastUsed];
        } else {
            DeviceStatus* ds = [[DeviceStatus alloc] init];
            ds.status = NO_DEVICE;
            ds.statusText = [NSString stringWithFormat:NSLocalizedString(@"Not able to connect to %@",@"LimiTTer: Not able to connect to device"),[lastUsed UUIDString]];
            ds.device = nil;
            [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:ds];
            self.lastDeviceStatus = ds;
        }
    }
}

-(BOOL) needsConnection {
    NSDictionary* deviceData = [[Storage instance] deviceData];
    NSUUID* lastUsed = [[NSUUID alloc] initWithUUIDString:[deviceData objectForKey:@"limitterUUID"]];
    if(!lastUsed)
        return YES;
    if(self.device.state == CBPeripheralStateDisconnected)
        return YES;
    return NO;
}

-(void)unregister {
    [self log:@"unregistering"];
    if(self.device && self.rx)
        [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_DISCONNECT_DEVICE object:self.device];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void) deviceRestored:(NSNotification*) notification {
    if([notification object]) {
        [self setDevice:[notification object]];
        DeviceStatus* ds = [[DeviceStatus alloc] init];
        ds.status = DEVICE_CONNECTING;
        ds.statusText = [NSString stringWithFormat:NSLocalizedString(@"Connecting to %@",@"limitter: connecting to device"),[[notification object] name]];
        ds.device = nil;
        [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:ds];
        self.lastDeviceStatus = ds;
        [self log:[NSString stringWithFormat:@"connecting to %@",[notification object]]];
        [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_CONNECT_DEVICE object:[notification object]];
    } else {
        NSDictionary* deviceData = [[Storage instance] deviceData];
        NSUUID* lastUsed = [deviceData objectForKey:@"limitterUUID"];
        if(lastUsed) {
            [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_RESTORE_DEVICE object:lastUsed];
        }
    }
}

-(void) deviceConnected:(NSNotification*) notification {
    if([[((CBPeripheral*)[notification object]).name lowercaseString] rangeOfString:@"limitter"].length!=0) {
        [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_STOP_SCAN object:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_DISCOVER_DEVICE object:[notification object]];
    }
}

-(void) disconnected:(NSNotification*) notification {
    if(![self device] || [[self device].identifier isEqual:((CBPeripheral*)[notification object]).identifier]) {
        DeviceStatus* ds = [[DeviceStatus alloc] init];
        ds.status = DEVICE_DISCONNECTED;
        ds.statusText = [NSString stringWithFormat:NSLocalizedString(@"Disconnected from %@, waiting for next",@"limitter: disconnect from device"),[[notification object] name]];
        ds.device = nil;
        [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:ds];
        self.lastDeviceStatus = ds;

        _rx = nil;
        if(!_shouldDisconnect) {
            [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_CONNECT_DEVICE object:[self device]];
        } else {
            [self setDevice:nil];
        }
    }
}
-(void) failed:(NSNotification*) notification {
    if(![self device] || [[[self device] identifier] isEqual:[(CBPeripheral*)[[notification object] objectForKey:@"peripheral"] identifier]]) {
        DeviceStatus* ds = [[DeviceStatus alloc] init];
        ds.status = DEVICE_DISCONNECTED;
        ds.statusText = [NSString stringWithFormat:NSLocalizedString(@"failed connection to %@",@"LimiTTer: failed connecting to device"),[[[notification object] objectForKey:@"peripheral"] name]];
        ds.device = nil;
        [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:ds];
        self.lastDeviceStatus = ds;

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
        if([service.UUID isEqual:[CBUUID UUIDWithString:BLUETOOTH_SERVICE_HM]]) {
            for(CBCharacteristic* chara in service.characteristics) {
                if([chara.UUID isEqual:[CBUUID UUIDWithString:BLUETOOTH_SERVICE_HM_RX_TX]]) {
                    [self.device setNotifyValue:YES forCharacteristic:chara];
                    _rx = chara;
                }else {
                    NSLog(@"found another characteristics: %@",[chara debugDescription]);
                }
            }
            if(_rx) {
                DeviceStatus* ds = [[DeviceStatus alloc] init];
                ds.status = DEVICE_CONNECTED;
                ds.statusText = [NSString stringWithFormat:NSLocalizedString(@"Connected to %@",@"limitter: connected device"),[self.device name]];
                ds.device = self.device;
                [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:ds];
                self.lastDeviceStatus = ds;

                [self log:[NSString stringWithFormat:@"connected to %@",[self.device identifier]]];
                [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_READ_CHARACTERISTIC
                                                                    object:_rx];
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

            NSArray* words = [s componentsSeparatedByCharactersInSet :[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString* trimmed = [words componentsJoinedByString:@""];
            BOOL found = NO;

            if([limitter isAllDigits:trimmed] && [trimmed length]>3)
            {
                int limitterValue = 0;
                int battery = 0;
                int minutes = 0;
                switch([words count]) {
                    case 4:
                        minutes = [[words objectAtIndex:3] intValue];
                        found = YES;
                    case 3:
                        limitterValue = [[words objectAtIndex:0] intValue];
                        battery = [[words objectAtIndex:2] intValue];
                        found = YES;
                        break;

                }
                if(found) {
                    NSString* rawSource = @"limitter";
                    [[Storage instance] addBatteryValue:battery raw:battery source:@"limitter" device:[self class]];

                    batteryValue* bV = [[batteryValue alloc] initWith:battery raw:battery from:@"limitter" class:[self class] at:[[NSDate date] timeIntervalSince1970]];
                    [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceBatteryValueNotification
                                                                        object:bV];

                    bgRawValue* rawValue = [[bgRawValue alloc] initWith:(((double)limitterValue)/1000.0) withData:data from:rawSource];
                    [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceRawValueNotification object:rawValue];

                    //FIXME add sensor
                    DeviceStatus* ds = [[DeviceStatus alloc] init];
                    ds.status = DEVICE_OK;
                    ds.statusText = NSLocalizedString(@"limitter ok",@"limitter: sensor ok");
                    ds.device = self.device;
                    [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:ds];
                    self.lastDeviceStatus = ds;
                }
            } else {
                    DeviceStatus* ds = [[DeviceStatus alloc] init];
                    ds.status = DEVICE_ERROR;
                    ds.statusText = NSLocalizedString(@"limitter failed",@"limitter: no data found");
                    ds.device = self.device;
                    [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:ds];
                    self.lastDeviceStatus = ds;
            }
        }
    }
}

+ (BOOL) isAllDigits:(NSString*)s {
    NSCharacterSet* nonNumbers = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    NSRange r = [s rangeOfCharacterFromSet: nonNumbers];
    return r.location == NSNotFound && s.length > 0;
}

#pragma mark -
#pragma mark configuration

+(NSString*) configurationName {
    return @"LimiTTer / SweetReader";
}

+(NSString*) configurationDescription {
    return NSLocalizedString(@"The LimiTTer or SweetReader is used to fetch values from the libre Tag.",@"limitter: Description");
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
        [deviceData setObject:[[peripheral identifier] UUIDString] forKey:@"limitterUUID"];
    } else {
        [deviceData removeObjectForKey:@"limitterUUID"];
    }
    [[Storage instance] saveDeviceData:deviceData];
    [[Configuration instance].device reload];
}

+(BOOL) compatibleService:(CBService*) service {
    if([[service UUID]  isEqual:[CBUUID UUIDWithString:BLUETOOTH_SERVICE_HM]])
        return YES;
    return NO;
}

-(NSArray*) getRequestedDeviceUUIDs {
    return [NSArray arrayWithObjects:[CBUUID UUIDWithString:BLUETOOTH_SERVICE_HM], nil];
}

+(BOOL) compatibleName:(CBPeripheral*) peripheral {
    if([[peripheral.name lowercaseString] rangeOfString:@"limitter"].length!=0)
        return YES;
    if([[peripheral.name lowercaseString] rangeOfString:@"sweetreader"].length!=0)
        return YES;
    return NO;
}

#pragma mark -
#pragma mark device Functions
-(int) batteryMaxValue {
    return 100;
}

-(int) batteryMinValue {
    return 0;
}

-(int) batteryFullValue {
    return 90;
}

-(int) batteryLowValue {
    return 20;
}

-(NSString*) settingsSequeIdentifier {
    return @"limitterDeviceSettings";
}
@end
