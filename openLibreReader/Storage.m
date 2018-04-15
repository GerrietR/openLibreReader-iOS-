//
//  BluetoothService.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "Storage.h"
#import <sqlite3.h>

#import "bgValue.h"
#import "batteryValue.h"
#import "calibrationValue.h"
#import "Device.h"

#import "Configuration.h"
#import "DatabaseUtils.h"

#define VALUES_DB @"value"
#define LOG_DB @"log"
#define BATTERY_DB @"battery"
#define CALIBRATION_DB @"calibration"

static Storage* __instance;

@interface Storage ()
    @property (strong,nonatomic) NSString* documentsDirectory;
    @property (nonatomic) sqlite3* db;
    @property (nonatomic) NSLock *dbLock;
    @property (nonatomic) sqlite3* log;
    @property (nonatomic) NSLock *logLock;
    @property (nonatomic) sqlite3* battery;
    @property (nonatomic) NSLock *batteryLock;
    @property (nonatomic) sqlite3* calibration;
    @property (nonatomic) NSLock *calibrationLock;
@end

@implementation Storage

+(instancetype)instance {
    if(__instance == nil)
        __instance = [[Storage alloc] init];
    return __instance;
}

- (instancetype)init {
    if(__instance)
        assert("wrong!");

    self = [super init];
    if (self) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        _documentsDirectory = [paths objectAtIndex:0];
        _dbLock = [[NSLock alloc] init];
        _logLock = [[NSLock alloc] init];
        _batteryLock = [[NSLock alloc] init];
        _calibrationLock = [[NSLock alloc] init];
        [_dbLock lock];
        [_logLock lock];
        [_batteryLock lock];
        [_calibrationLock lock];
        [self openValueDB];
        [self openLogDB];
        [self openBatteryDB];
        [self openCalibrationDB];

        if(![self executeQuery:@"CREATE TABLE IF NOT EXISTS log (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, timestamp INTEGER, message TEXT, modul TEXT)" onDB:_log]){
            [self closeValueDB];
            [self closeLogDB];
            [self closeBatteryDB];
            [self closeCalibrationDB];
            return nil;
        }
        [DatabaseUtils ensureDefinition:@{@"tablename":@"log",
                                          @"fields":@[
                                                  @{@"cid":[NSNumber numberWithInt:0],
                                                    @"name":@"id",
                                                    @"type":@"INTEGER",
                                                    @"notnull":[NSNumber numberWithInt:1],
                                                    //@"dflt_value":NULL,
                                                    @"pk":[NSNumber numberWithInt:1]
                                                    },
                                                  @{@"cid":[NSNumber numberWithInt:1],
                                                    @"name":@"timestamp",
                                                    @"type":@"INTEGER",
                                                    @"notnull":[NSNumber numberWithInt:0],
                                                    //@"dflt_value":NULL,
                                                    @"pk":[NSNumber numberWithInt:0]
                                                    },
                                                  @{@"cid":[NSNumber numberWithInt:2],
                                                    @"name":@"message",
                                                    @"type":@"TEXT",
                                                    @"notnull":[NSNumber numberWithInt:0],
                                                    //@"dflt_value":NULL,
                                                    @"pk":[NSNumber numberWithInt:0]
                                                    },
                                                  @{@"cid":[NSNumber numberWithInt:3],
                                                    @"name":@"modul",
                                                    @"type":@"TEXT",
                                                    @"notnull":[NSNumber numberWithInt:0],
                                                    //@"dflt_value":NULL,
                                                    @"pk":[NSNumber numberWithInt:0]
                                                    }]} database:_log];
        
        if(![self executeQuery:@"CREATE TABLE IF NOT EXISTS bg_values (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, timestamp INTEGER, raw_source TEXT, raw_data BLOB, value INTEGER, value_module TEXT, value_data BLOB)" onDB:_db]){
            [self closeValueDB];
            [self closeLogDB];
            [self closeBatteryDB];
            [self closeCalibrationDB];
            return nil;
        }
        if(![self executeQuery:@"CREATE TABLE IF NOT EXISTS battery (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, timestamp INTEGER, source TEXT, volts INTEGER, raw INTEGER, device TEXT)" onDB:_battery]){
            [self closeValueDB];
            [self closeLogDB];
            [self closeBatteryDB];
            [self closeCalibrationDB];
            return nil;
        }
        if(![self executeQuery:@"CREATE TABLE IF NOT EXISTS calibration (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, timestamp INTEGER, value INTEGER,  reference_value INTEGER, calibration_module TEXT)" onDB:_calibration]){
            [self closeValueDB];
            [self closeLogDB];
            [self closeBatteryDB];
            [self closeCalibrationDB];
            return nil;
        }

        [self closeValueDB];
        [self closeLogDB];
        [self closeBatteryDB];
        [self closeCalibrationDB];
        [_dbLock unlock];
        [_logLock unlock];
        [_batteryLock unlock];
        [_calibrationLock unlock];

    }
    return self;
}

#pragma mark -
#pragma mark db handling
-(BOOL) openValueDB {
    @try{
        if(_db)
            return true;
        return sqlite3_open([[_documentsDirectory stringByAppendingPathComponent:[VALUES_DB stringByAppendingString:@".sqlite"] ] UTF8String], &_db) != SQLITE_OK;
    }@catch(NSException *e){
        NSLog(@"got error on %@",[e debugDescription]);
    }
    return NO;
}

-(void) closeValueDB {
    @try{
        if(_db)
            sqlite3_close(_db);
        _db = nil;
    }@catch(NSException *e){
        NSLog(@"got error on %@",[e debugDescription]);
    }
}

-(BOOL) openCalibrationDB {
    @try{
        if(_calibration)
            return true;
        return sqlite3_open([[_documentsDirectory stringByAppendingPathComponent:[CALIBRATION_DB stringByAppendingString:@".sqlite"] ] UTF8String], &_calibration) != SQLITE_OK;
    }@catch(NSException *e){
        NSLog(@"got error on %@",[e debugDescription]);
    }
    return NO;
}

-(void) closeCalibrationDB {
    @try{
        if(_calibration)
            sqlite3_close(_calibration);
        _calibration = nil;
    }@catch(NSException *e){
        NSLog(@"got error on %@",[e debugDescription]);
    }
}

-(BOOL) openLogDB{
    @try{
        if(_log)
            return true;
        if(sqlite3_open([[_documentsDirectory stringByAppendingPathComponent:[LOG_DB stringByAppendingString:@".sqlite"] ] UTF8String], &_log) == SQLITE_OK)
        {
            return YES;
        }
    }@catch(NSException *e){
        NSLog(@"got error on %@",[e debugDescription]);
    }
    return NO;
}

-(void) closeLogDB {
    @try{
        if(_log)
            sqlite3_close(_log);
        _log = nil;
    }@catch(NSException *e){
        NSLog(@"got error on %@",[e debugDescription]);
    }
}

-(BOOL) openBatteryDB {
    @try{
        if(_battery)
            return true;
        return sqlite3_open([[_documentsDirectory stringByAppendingPathComponent:[BATTERY_DB stringByAppendingString:@".sqlite"] ] UTF8String], &_battery) != SQLITE_OK;
    }@catch(NSException *e){
        NSLog(@"got error on %@",[e debugDescription]);
    }
    return NO;
}

-(void) closeBatteryDB {
    @try{
        if(_battery)
            sqlite3_close(_battery);
        _battery = nil;
    }@catch(NSException *e){
        NSLog(@"got error on %@",[e debugDescription]);
    }
}

-(BOOL) executeQuery:(NSString *)query onDB:(sqlite3*)db{
    BOOL isExecuted = NO;

    sqlite3_stmt *statement = nil;
    const char *sql = [query UTF8String];
    if (sqlite3_prepare_v2(db, sql, -1, &statement , NULL) != SQLITE_OK) {
        return isExecuted;
    }

    if(SQLITE_DONE == sqlite3_step(statement)) {
        isExecuted = YES;
    }
    sqlite3_finalize(statement);
    statement = nil;

    return isExecuted;
}

#pragma mark -
#pragma mark db functions
-(BOOL) log:(NSString*)message from:(NSString*)from {
    @try {
        [_logLock lock];
        NSLog(@"[%@]: %@", from, message);
        [self openLogDB];
        BOOL r =  [self executeQuery:[NSString stringWithFormat:@"INSERT INTO log (timestamp,message,modul) VALUES (\"%ld\",\"%@\",\"%@\")", (unsigned long)[[NSDate date] timeIntervalSince1970], message, from] onDB:_log];
        [self closeLogDB];
        [_logLock unlock];
        return r;
    }@catch(NSException *e){
        NSLog(@"got error on %@",[e debugDescription]);
    }
    return NO;
}

-(BOOL) addBGValue:(int)value valueModule:(NSString*)value_module valueData:(NSData*)value_data valueTime:(unsigned long)seconds rawSource:(NSString*)raw_source rawData:(NSData*)raw_data {
    @try{
        [_dbLock lock];
        [self openValueDB];
        sqlite3_stmt *statement = nil;
        if (sqlite3_prepare_v2(_db, "INSERT INTO bg_values (timestamp,raw_source,raw_data,value,value_module,value_data) VALUES (?,?,?,?,?,?)", -1, &statement, NULL) == SQLITE_OK) {
            sqlite3_bind_int64(statement, 1, seconds);
            sqlite3_bind_text(statement, 2, [raw_source UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_blob(statement, 3, [raw_data bytes], (int)[raw_data length], SQLITE_TRANSIENT);
            sqlite3_bind_int(statement, 4, value);
            sqlite3_bind_text(statement, 5, [value_module UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_blob(statement, 6, [value_data bytes], (int)[value_data length], SQLITE_TRANSIENT);
        } else {
            [self log:@"unable to prepare add value" from:@"Storage"];

            [self closeValueDB];
            return false;
        }
        if (sqlite3_step(statement) != SQLITE_DONE) {
            [self log:@"unable to save add value" from:@"Storage"];

            [self closeValueDB];
            return false;
        }

        // Clean up and delete the resources used by the prepared statement.
        sqlite3_finalize(statement);

        [self closeValueDB];
        [_dbLock unlock];
        return true;
    }@catch(NSException *e){
        NSLog(@"got error on %@",[e debugDescription]);
    }
    return NO;
}

-(NSArray*) bgValuesFrom:(NSTimeInterval)from to:(NSTimeInterval)to {
    NSMutableArray* values = [NSMutableArray array];
    @try{
        [_dbLock lock];
        [self openValueDB];
        sqlite3_stmt *statement = nil;
        if (sqlite3_prepare_v2(_db, "select value, timestamp, raw_source from bg_values where timestamp > ? and timestamp <= ?", -1, &statement, NULL) == SQLITE_OK) {
            sqlite3_bind_int64(statement, 1, (unsigned long)from);
            sqlite3_bind_int64(statement, 2, (unsigned long)to);
        } else{
            [self log:@"unable to prepare valuesFrom:to:" from:@"Storage"];
            [self closeValueDB];
            return nil;
        }

        while (sqlite3_step(statement) == SQLITE_ROW) {
            int value = sqlite3_column_int(statement, 0);
            long long timestamp = sqlite3_column_int64(statement, 1);
            const char* source = (char*)sqlite3_column_text(statement, 2);
            bgValue* v = [[bgValue alloc] initWith:value from:[NSString stringWithCString:source encoding:NSUTF8StringEncoding] at:timestamp delta:NAN raw:nil];
            [values addObject:v];
        }
        sqlite3_finalize(statement);

        [self closeValueDB];
        [_dbLock unlock];
    }@catch(NSException *e){
        NSLog(@"got error on %@",[e debugDescription]);
    }
    return values;
}

-(NSTimeInterval) lastBGValue {
    @try{
        [_dbLock lock];

        [self openValueDB];
        sqlite3_stmt *statement = nil;
        if (sqlite3_prepare_v2(_db, "select timestamp from bg_values where 1 order by timestamp desc limit 1", -1, &statement, NULL) == SQLITE_OK) {

        } else{
            [self log:@"unable to get last bg" from:@"Storage"];
            [self closeValueDB];
            return 0;
        }

        long long timestamp=0;
        if (sqlite3_step(statement) == SQLITE_ROW) {
            timestamp = sqlite3_column_int64(statement, 0);
        }
        sqlite3_finalize(statement);

        [self closeValueDB];
        [_dbLock unlock];
        return timestamp;
    }@catch(NSException *e){
        NSLog(@"got error on %@",[e debugDescription]);
    }
    return 0;
}

-(bgValue*) lastBgBefore:(NSTimeInterval)before {
    @try{
        [_dbLock lock];
        [self openValueDB];
        sqlite3_stmt *statement = nil;
        if (sqlite3_prepare_v2(_db, "select value, timestamp, raw_source from bg_values where timestamp < ? order by timestamp desc limit 1", -1, &statement, NULL) == SQLITE_OK) {
            sqlite3_bind_int64(statement, 1, (unsigned long)before);
        } else{
            [self log:@"unable to get last bg before" from:@"Storage"];
            [self closeValueDB];
            return nil;
        }

        bgValue* bg = nil;
        if (sqlite3_step(statement) == SQLITE_ROW) {
            int value = sqlite3_column_int(statement, 0);
            unsigned long timestamp = sqlite3_column_int64(statement, 1);
            const char* source = (char*)sqlite3_column_text(statement, 2);
            bg = [[bgValue alloc] initWith:value from:[NSString stringWithCString:source encoding:NSUTF8StringEncoding] at:timestamp delta:NAN raw:nil];
        }
        sqlite3_finalize(statement);

        [self closeValueDB];
        [_dbLock unlock];
        return bg;
    }@catch(NSException *e){
        NSLog(@"got error on %@",[e debugDescription]);
    }
    return nil;
}

-(bgRawValue*) lastRawBgBefore:(NSTimeInterval)before {
    @try{
        [_dbLock lock];
        [self openValueDB];
        sqlite3_stmt *statement = nil;
        if (sqlite3_prepare_v2(_db, "select raw_source,raw_data from bg_values where timestamp < ? order by timestamp desc limit 1", -1, &statement, NULL) == SQLITE_OK) {
            sqlite3_bind_int64(statement, 1, (unsigned long)before);
        } else{
            [self log:@"unable to get last bg before" from:@"Storage"];
            [self closeValueDB];
            return nil;
        }

        bgRawValue* bg = nil;
        if (sqlite3_step(statement) == SQLITE_ROW) {
            const char* source = (char*)sqlite3_column_text(statement, 0);
            const void *raw_ptr = sqlite3_column_blob(statement, 1);
            int raw_size = sqlite3_column_bytes(statement, 1);
            NSData* raw_data = [[NSData alloc] initWithBytes:raw_ptr length:raw_size];
            const double value =sqlite3_column_double(statement, 2);

            bg = [[bgRawValue alloc] initWith:value withData:raw_data from:[NSString stringWithCString:source encoding:NSUTF8StringEncoding]];

        }
        sqlite3_finalize(statement);

        [self closeValueDB];
        [_dbLock unlock];
        return bg;
    }@catch(NSException *e){
        NSLog(@"got error on %@",[e debugDescription]);
    }
    return nil;
}

-(BOOL) addBatteryValue:(int)volt raw:(int)raw source:(NSString*)source device:(Class)device {
    @try {
        [_batteryLock lock];
        [self openBatteryDB];
        sqlite3_stmt *statement = nil;
        if (sqlite3_prepare_v2(_battery, "INSERT INTO battery (timestamp,source,volts,raw,device) VALUES (?,?,?,?,?)", -1, &statement, NULL) == SQLITE_OK) {
            sqlite3_bind_int64(statement, 1, (unsigned long)[[NSDate date] timeIntervalSince1970]);
            sqlite3_bind_text(statement, 2, [source UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_int(statement, 3, volt);
            sqlite3_bind_int(statement, 4, raw);
            sqlite3_bind_text(statement, 5, [NSStringFromClass(device) UTF8String], -1, SQLITE_TRANSIENT);
        }
        else{
            [self log:@"unable to prepare add battery" from:@"Storage"];

            [self closeBatteryDB];
            return false;
        }
        if (sqlite3_step(statement) != SQLITE_DONE) {
            [self log:@"unable to save add battery" from:@"Storage"];

            [self closeBatteryDB];
            return false;
        }

        // Clean up and delete the resources used by the prepared statement.
        sqlite3_finalize(statement);

        [self closeBatteryDB];
        [_batteryLock unlock];
        return true;
    }@catch(NSException *e){
        NSLog(@"got error on %@",[e debugDescription]);
    }
    return NO;
}

-(NSArray*) batteryValuesFrom:(NSTimeInterval)from to:(NSTimeInterval)to {
    NSMutableArray* values = [NSMutableArray array];
    @try {
        [_batteryLock lock];
        [self openBatteryDB];
        sqlite3_stmt *statement = nil;
        if (sqlite3_prepare_v2(_battery, "select timestamp, volts, raw, source, device from battery where timestamp > ? and timestamp < ?", -1, &statement, NULL) == SQLITE_OK) {
            sqlite3_bind_int64(statement, 1, (unsigned long)from);
            sqlite3_bind_int64(statement, 2, (unsigned long)to);
        } else{
            [self log:@"unable to prepare batteryFrom:to:" from:@"Storage"];
            [self closeBatteryDB];
            return nil;
        }

        while (sqlite3_step(statement) == SQLITE_ROW) {
            long long timestamp = sqlite3_column_int64(statement, 0);
            int volt = sqlite3_column_int(statement, 1);
            int raw = sqlite3_column_int(statement, 2);
            NSString* source = [NSString stringWithUTF8String:(char*)sqlite3_column_text(statement, 3)];
            NSString* device = [NSString stringWithUTF8String:(char*)sqlite3_column_text(statement, 4)];

            batteryValue* v = [[batteryValue alloc] initWith:volt raw:raw from:source class:NSClassFromString(device) at:timestamp];
            [values addObject:v];
        }
        sqlite3_finalize(statement);

        [self closeBatteryDB];
        [_batteryLock unlock];
    }@catch(NSException *e){
        NSLog(@"got error on %@",[e debugDescription]);
    }
    return values;
}


-(BOOL) addCalibration:(int)value reference:(int)reference valueTime:(unsigned long)seconds module:(NSString*)module {
    [_calibrationLock lock];
    @try {
        [self openCalibrationDB];
        sqlite3_stmt *statement = nil;
        if (sqlite3_prepare_v2(_calibration, "INSERT INTO calibration (timestamp, value, reference_value, calibration_module) VALUES (?,?,?,?)", -1, &statement, NULL) == SQLITE_OK) {
            sqlite3_bind_int64(statement, 1, seconds);
            sqlite3_bind_int(statement, 2, value);
            sqlite3_bind_int(statement, 3, reference);
            sqlite3_bind_text(statement, 4, [module UTF8String], -1, SQLITE_TRANSIENT);
        }
        else{
            [self log:@"unable to prepare add calibration" from:@"Storage"];
            
            [self closeCalibrationDB];
            return false;
        }
        if (sqlite3_step(statement) != SQLITE_DONE) {
            [self log:@"unable to save add calibration" from:@"Storage"];
            
            [self closeCalibrationDB];
            return false;
        }
        
        // Clean up and delete the resources used by the prepared statement.
        sqlite3_finalize(statement);
        
        [self closeCalibrationDB];
        return true;
    }@catch(NSException *e){
        NSLog(@"got error on %@",[e debugDescription]);
    }
    @finally {
        [_calibrationLock unlock];
    }
    return NO;
}

-(NSArray*) calibrationFrom:(NSTimeInterval)from to:(NSTimeInterval)to {
    NSMutableArray* values = [NSMutableArray array];
    [_calibrationLock lock];
    @try {
        [self openCalibrationDB];
        sqlite3_stmt *statement = nil;
        if (sqlite3_prepare_v2(_calibration, "select timestamp, value, reference_value, calibration_module from calibration where timestamp > ? and timestamp <= ? order by timestamp desc", -1, &statement, NULL) == SQLITE_OK) {
            sqlite3_bind_int64(statement, 1, (unsigned long)from);
            sqlite3_bind_int64(statement, 2, (unsigned long)to);
        } else{
            [self log:@"unable to prepare calibrationFrom:to:" from:@"Storage"];
            [self closeCalibrationDB];
            return nil;
        }
        
        while (sqlite3_step(statement) == SQLITE_ROW) {
            long long timestamp = sqlite3_column_int64(statement, 0);
            int value = sqlite3_column_int(statement, 1);
            int reference = sqlite3_column_int(statement, 2);
            NSString* module = [NSString stringWithUTF8String:(char*)sqlite3_column_text(statement, 3)];
            
            calibrationValue* v = [[calibrationValue alloc] initWith:value reference:reference from:module at:timestamp];
            [values addObject:v];
        }
        sqlite3_finalize(statement);
        [self closeCalibrationDB];
    }
    @catch(NSException *e){
        NSLog(@"got error on %@",[e debugDescription]);
    }
    @finally {
        [_calibrationLock unlock];
    }
    return values;
}

-(void) deleteCalibration:(NSTimeInterval)timestamp module:(NSString*) module
{
    [_calibrationLock lock];
    @try {
        [self openCalibrationDB];
        sqlite3_stmt *statement = nil;
        if (sqlite3_prepare_v2(_calibration, "delete from calibration where timestamp = ? and calibration_module = ?", -1, &statement, NULL) == SQLITE_OK) {
            sqlite3_bind_int64(statement, 1, (unsigned long)timestamp);
            sqlite3_bind_text(statement, 2, [module UTF8String], -1, SQLITE_TRANSIENT);
        } else{
            [self log:@"unable to prepare deleteCalibration" from:@"Storage"];
            [self closeCalibrationDB];
            return;
        }
        int dbrc = 0;
        if ((dbrc = sqlite3_step(statement)) != SQLITE_DONE) {
            NSLog(@"couldn't delete calibration with timestamp %f from datasets: result code %i", timestamp, dbrc);
            [self closeCalibrationDB];
            return;
        }
        else {
            NSLog(@"deleted the calibration with timestamp %f from datasets", timestamp);
        };
        sqlite3_finalize(statement);
        
        [self closeCalibrationDB];
    }
    @catch(NSException *e){
        NSLog(@"got error on %@",[e debugDescription]);
    }
    @finally {
        [_calibrationLock unlock];
    }
    
};

#pragma mark -
#pragma mark deviceData

-(NSMutableDictionary*) deviceData {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary* savedData = [defaults objectForKey:@"deviceData"];
    return [[NSMutableDictionary alloc] initWithDictionary:savedData];
}

-(void) saveDeviceData:(NSDictionary*)deviceData {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if(deviceData)
        [defaults setObject:deviceData forKey:@"deviceData"];
    else
        [defaults removeObjectForKey:@"deviceData"];
    [defaults synchronize];
}

#pragma mark -
#pragma mark baseSettings
-(NSString*) getSelectedDeviceClass {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:@"DeviceClass"];
}

-(NSString*) getSelectedCalibrationClass {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:@"CalibrationClass"];
}

-(void) setSelectedDeviceClass:(NSString*)deviceClass {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:deviceClass forKey:@"DeviceClass"];
    [defaults synchronize];
}

-(void) setSelectedCalibrationClass:(NSString*)calibrationClass {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:calibrationClass forKey:@"CalibrationClass"];
    [defaults synchronize];
}

-(NSString*) getSelectedDisplayUnit {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:@"DisplayUnit"];
}

-(void) setSelectedDisplayUnit:(NSString*)unit {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:unit forKey:@"DisplayUnit"];
    [defaults synchronize];
}
-(NSMutableDictionary*)getAlarmData {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if(![defaults objectForKey:@"alarmData"]) return [Configuration defaultAlarmData];
    return [NSMutableDictionary dictionaryWithDictionary:[defaults objectForKey:@"alarmData"]];
}
-(void)setAlarmData:(NSMutableDictionary*)alarmData {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:alarmData forKey:@"alarmData"];
    [defaults synchronize];
}
-(NSMutableDictionary*)getBGData {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if(![defaults objectForKey:@"bgData"]) return [Configuration defaultBGData];
    return [NSMutableDictionary dictionaryWithDictionary:[defaults objectForKey:@"bgData"]];
}
-(void)setBGData:(NSMutableDictionary*)alarmData {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:alarmData forKey:@"bgData"];
    [defaults synchronize];
}
-(NSMutableDictionary*)getGeneralData {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if(![defaults objectForKey:@"general"]) return [Configuration defaultGeneralData];
    return [NSMutableDictionary dictionaryWithDictionary:[defaults objectForKey:@"general"]];
}
-(void)setGeneralData:(NSMutableDictionary*)general {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:general forKey:@"general"];
    [defaults synchronize];
}
-(NSMutableDictionary*)getNSData {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if(![defaults objectForKey:@"nightscout"]) return [Configuration defaultNSData];
    return [NSMutableDictionary dictionaryWithDictionary:[defaults objectForKey:@"nightscout"]];
}
-(void)setNSData:(NSMutableDictionary*)ns {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:ns forKey:@"nightscout"];
    [defaults synchronize];
}
-(void)setAgree:(BOOL)agreed {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithBool:agreed] forKey:@"agreed"];
    [defaults synchronize];
}
-(BOOL)agreed {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [[defaults objectForKey:@"agreed"] boolValue];
}

@end
