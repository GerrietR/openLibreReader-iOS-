//
//  BluetoothService.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "nightscout.h"
#import "Storage.h"
#import "Configuration.h"
#import "bgValue.h"
#import "AppDelegate.h"
#import "nightscoutDeviceViewController.h"

@import SocketIO;

@interface nightscout ()
    @property long lastSGV;
    @property (retain) SocketIOClient* socket;
    @property BOOL shuttingDown;
@end

@implementation nightscout

- (instancetype)init {
    self = [super init];
    if (self) {
        [self reload];
        _lastSGV=0;
    }
    return self;
}

-(void) willSuspend:(NSNotification*)notification {
    _shuttingDown=YES;
    [_socket disconnect];
}

-(void) didActivate:(NSNotification*)notification {
    if(_shuttingDown)
        [self reload];
}

-(void) reload {
    _shuttingDown = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestStatus:) name:kDeviceRequestStatusNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willSuspend:) name:kAppWillSuspend object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didActivate:) name:kAppDidActivate object:nil];

    if([_socket status] != SocketIOClientStatusNotConnected && [_socket status] != SocketIOClientStatusDisconnected) {
        [_socket disconnect];
    }

    DeviceStatus* ds = [[DeviceStatus alloc] init];
    ds.status = DEVICE_DISCONNECTED;
    ds.statusText = [NSString stringWithFormat:NSLocalizedString(@"reloading",@"nightscout: reloading")];
    ds.device = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:ds];
    self.lastDeviceStatus = ds;

    if([[Storage instance] deviceData] && [[[Storage instance] deviceData] objectForKey:@"nightscoutURL"])
    {
        NSURL* url = [[NSURL alloc] initWithString:[[[Storage instance] deviceData] objectForKey:@"nightscoutURL"]];

        _socket = [[SocketIOClient alloc] initWithSocketURL:url config:@{@"log": @NO, @"compress": @YES}];

        [_socket on:@"connect" callback:^(NSArray* data, SocketAckEmitter* ack) {
            DeviceStatus* ds = [[DeviceStatus alloc] init];
            ds.status = DEVICE_CONNECTED;
            ds.statusText = [NSString stringWithFormat:NSLocalizedString(@"connected",@"nightscout: connected")];
            ds.device = nil;
            [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:ds];
            self.lastDeviceStatus = ds;
            NSDictionary* deviceData = [[Storage instance] deviceData];
            NSObject* onj = [deviceData objectForKey:@"lastSGV"];
            if([onj isKindOfClass:[NSNumber class]])
                _lastSGV = [((NSNumber*)onj) longValue];
            NSDictionary* answer = @{@"client": @"iOS_openLibreReader",
                                     @"history":[NSNumber numberWithInt:48],
                                     @"status":@"true",
                                     @"from": [NSNumber numberWithLong:_lastSGV+1000],
                                     @"secret": [[[Storage instance] deviceData] objectForKey:@"nightscoutHash"]};
            [[_socket emitWithAck:@"authorize" with:@[answer]] timingOutAfter:10 callback:^(NSArray * muh) {
                if([muh isEqual:@"NO ACK"]) {
                    [_socket disconnect];
                    [self reload];
                }
            }];

        }];
        [_socket on:@"disconnect" callback:^(NSArray* data, SocketAckEmitter* ack) {
            DeviceStatus* ds = [[DeviceStatus alloc] init];
            ds.status = DEVICE_DISCONNECTED;
            ds.statusText = [NSString stringWithFormat:NSLocalizedString(@"lost connection",@"nightscout: disconnected")];
            ds.device = nil;
            [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:ds];
            self.lastDeviceStatus = ds;
            if(!_shuttingDown) {
                [self reload];
            }
        }];
        [self.socket onAny:^(SocketAnyEvent* any) {
            NSString* event = any.event;
            NSArray* data = any.items;
            [self log:[NSString stringWithFormat:@"any: %@ %@",event,data]];
        }];
        [_socket on:@"ping" callback:^(NSArray* data, SocketAckEmitter* ack) {}];
        [_socket on:@"dataUpdate" callback:^(NSArray* data, SocketAckEmitter* ack) {
            [self log:[NSString stringWithFormat:@"dataUpdate recieved"]];
            DeviceStatus* ds = [[DeviceStatus alloc] init];
            ds.status = DEVICE_OK;
            ds.statusText = [NSString stringWithFormat:NSLocalizedString(@"connected, recieving",@"nightscout: recieving")];
            ds.device = nil;
            [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:ds];
            self.lastDeviceStatus = ds;
            for(NSDictionary* dataPart in data) {
                if([dataPart objectForKey:@"sgvs"]) {
                    NSArray* sgvs =[dataPart objectForKey:@"sgvs"];
                    for(NSDictionary* sgv in sgvs) {
                        _lastSGV = MAX(_lastSGV, [[sgv objectForKey:@"mills"] longValue]);

                        [self log:[NSString stringWithFormat:@"[nightscout] recieved Value %f",[[sgv objectForKey:@"mgdl"] doubleValue]]];
                        [[Storage instance] addBGValue:[[sgv objectForKey:@"mgdl"] intValue]
                                           valueModule:@"Calibration"
                                             valueData:nil
                                             valueTime:[[sgv objectForKey:@"mills"] longValue]/1000
                                             rawSource:@"nightscout"
                                               rawData:[NSKeyedArchiver archivedDataWithRootObject:sgv]];
                        bgValue* bgV = [[bgValue alloc] initWith:[[sgv objectForKey:@"mgdl"] intValue]
                                                            from:@"nightscout"
                                                              at:[[sgv objectForKey:@"mills"] longValue]/1000
                                                           delta:NAN raw:nil];
                        [[NSNotificationCenter defaultCenter] postNotificationName:kCalibrationBGValue object:bgV];
                    }
                }
            }

            NSMutableDictionary* deviceData = [[Storage instance] deviceData];
            [deviceData setObject:[NSNumber numberWithLong:_lastSGV] forKey:@"lastSGV"];
            [[Storage instance] saveDeviceData:deviceData];
        }];
        ds = [[DeviceStatus alloc] init];
        ds.status = DEVICE_CONNECTING;
        ds.statusText = [NSString stringWithFormat:NSLocalizedString(@"connecting",@"nightscout: connecting")];
        ds.device = nil;
        [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:ds];
        self.lastDeviceStatus = ds;

        [_socket connectWithTimeoutAfter:10 withHandler:^{
            [self log:[NSString stringWithFormat:@"failed to connect: %@",_socket.debugDescription]];
            DeviceStatus* ds = [[DeviceStatus alloc] init];
            ds.status = DEVICE_DISCONNECTED;
            ds.statusText = [NSString stringWithFormat:NSLocalizedString(@"failed to connect",@"nightscout: failed")];
            ds.device = nil;
            [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:ds];
            self.lastDeviceStatus = ds;
        }];
    } else {
        ds = [[DeviceStatus alloc] init];
        ds.status = DEVICE_ERROR;
        ds.statusText = [NSString stringWithFormat:NSLocalizedString(@"error, no data",@"nightscout: connect nor url")];

        ds.device = nil;
        [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:ds];
        self.lastDeviceStatus = ds;
    }
}

-(void) requestStatus:(NSNotification*)notification {
    if(self.lastDeviceStatus) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceStatusNotification object:self.lastDeviceStatus];
    }
}

-(BOOL) needsConnection {
    NSDictionary* deviceData = [[Storage instance] deviceData];
    NSString* url = [deviceData objectForKey:@"url"];
    NSString* hash = [deviceData objectForKey:@"hash"];
    if(url && hash)
        return NO;
    return YES;
}

-(void)unregister
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -
#pragma mark configuration

+(NSString*) configurationName {
    return @"Nightscout client";
}

+(NSString*) configurationDescription {
    return NSLocalizedString(@"Values are recieved from a Nightscout instance.\nAlarms might stop working, if app is not actively showing.",@"nightscout: Description");
}

+(UIViewController*) configurationViewController {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];

    UIViewController* vc = [storyboard instantiateViewControllerWithIdentifier:@"NightscoutDeviceViewController"];
    ((nightscoutDeviceViewController*)vc).hideOnSuccess = YES;
    return vc;
}

#pragma mark -
#pragma mark device Functions
-(int) batteryMaxValue {
    return 1024;
}

-(int) batteryMinValue {
    return 750;
}

-(int) batteryFullValue {
    return 925;
}

-(int) batteryLowValue {
    return 850;
}

-(NSString*) settingsSequeIdentifier {
    return @"nightscoutDevice";
}
@end

@implementation nightscoutUploader

-(instancetype)init {
    self = [super init];
    if(self) {
        [self reload];
    }
    return self;
}
-(void) reload {
    if([[Configuration instance] nsUpload] && ![[[Storage instance] getSelectedDeviceClass] isEqualToString:NSStringFromClass([nightscout class])]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newBG:) name:kCalibrationBGValue object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}
/**
 adopted from https://github.com/jamorham/xDrip-plus/blob/master/app/src/main/java/com/eveningoutpost/dexdrip/Models/BgReading.java#L582
 */
+(NSString*) slopeName:(double)slope_by_minute {
    NSString* arrow = @"NONE";
    if (slope_by_minute <= (-3.5)) {
        arrow = @"DoubleDown";
    } else if (slope_by_minute <= (-2)) {
        arrow = @"SingleDown";
    } else if (slope_by_minute <= (-1)) {
        arrow = @"FortyFiveDown";
    } else if (slope_by_minute <= (1)) {
        arrow = @"Flat";
    } else if (slope_by_minute <= (2)) {
        arrow = @"FortyFiveUp";
    } else if (slope_by_minute <= (3.5)) {
        arrow = @"SingleUp";
    } else if (slope_by_minute <= (40)) {
        arrow = @"DoubleUp";
    }
    /*if (hide_slope) {
        arrow = "NOT COMPUTABLE";
    }*/
    return arrow;
}

-(void) newBG:(NSNotification*)notification {
    bgValue* bg = notification.object;

    if(bg.raw == nil || bg.deltaPerMinute==NAN) {
        [[Storage instance] log:@"unable to upload incomplete bg value!" from:@"nighscoutUploader"];
        return;
    }

    NSDateFormatter *objDateFormatter = [[NSDateFormatter alloc] init];
    [objDateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZ"];
    [objDateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"US"]];
    NSDictionary* dic = @{
                          @"device":[@"openLibreReader-ios-" stringByAppendingString:bg.raw.rawSource],
                          @"date":[NSNumber numberWithDouble:bg.timestamp*1000.0],
                          @"dateString":[objDateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:bg.timestamp]],
                          @"sgv":[NSNumber numberWithInt:bg.value],
                          @"direction":[nightscoutUploader slopeName:bg.deltaPerMinute],
                          @"type":@"sgv",
                          @"filtered":[NSNumber numberWithInt:bg.value],// FIXME needed?
                          @"unfiltered":[NSNumber numberWithDouble:bg.raw.rawValue],
                          @"rssi":[NSNumber numberWithInt:100],// FIXME needed?
                          @"noise":[NSNumber numberWithInt:1],// FIXME needed?
                          @"delta":(isnan(bg.deltaPerMinute)?[NSNumber numberWithDouble:0]:[NSNumber numberWithDouble:bg.deltaPerMinute]),
                          @"sysTime": [objDateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:bg.timestamp]]
                          };
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic
                                                       options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                         error:&error];

    if (! jsonData) {
        NSLog(@"Got an error: %@", error);
    } else {
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        [request setHTTPMethod:@"POST"];
        [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request addValue:[[Configuration instance] nightscoutUploadHash] forHTTPHeaderField:@"api-secret"];
        [request setURL:[NSURL URLWithString:[[[Configuration instance] nightscoutUploadURL] stringByAppendingString:@"/api/v1/entries"]]];
         [request setHTTPBody:jsonData];
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration
                                                    defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
        NSURLSessionDataTask *postDataTask = [session dataTaskWithRequest:request
                                                        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
                                              {
                                                  if (!error) {
                                                      [[Storage instance] log:@"upload complete!" from:@"nighscoutUploader"];
                                                  } else {
                                                      [[Storage instance] log:[NSString stringWithFormat:@"error in upload: %@",[error debugDescription]] from:@"nighscoutUploader"];
                                                  }
                                              }];
        [postDataTask resume];
    }
}
@end
