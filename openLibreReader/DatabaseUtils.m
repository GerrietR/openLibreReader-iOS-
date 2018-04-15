//
//  BluetoothService.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "DatabaseUtils.h"


@implementation DatabaseUtils

+(BOOL) ensureDefinition:(NSDictionary*)definition database:(sqlite3*)db {
    sqlite3_stmt *statement = nil;
    const char *sql = [[NSString stringWithFormat:@"PRAGMA table_info(%@)",[definition objectForKey:@"tablename"]] UTF8String];
    if (sqlite3_prepare_v2(db, sql, -1, &statement , NULL) != SQLITE_OK) {
        return false;
    }
    int index = 0;
    while (sqlite3_step(statement) == SQLITE_ROW) {
        NSDictionary* field = nil;
        if([[definition objectForKey:@"fields"] count] > index)
            field = [[definition objectForKey:@"fields"] objectAtIndex:index];
        int cid = sqlite3_column_int(statement, 0);
        const char* name = (char*)sqlite3_column_text(statement, 1);
        const char* type = (char*)sqlite3_column_text(statement, 2);
        int notnull = sqlite3_column_int(statement, 3);
        const char* dflt_value = (char*)sqlite3_column_text(statement, 4);
        int pk = sqlite3_column_int(statement, 5);

        if(!field) {
            NSLog(@"to many fields in database: index[%d]= [%d,%s,%s,%d,%s,%d]",index,
                  cid, name, type, notnull,(dflt_value?dflt_value:"NULL"),pk);
        } else {
            if([[field objectForKey:@"cid"] intValue] == cid &&
               [[field objectForKey:@"name"] isEqualToString:[NSString stringWithUTF8String:name]] &&
               [[field objectForKey:@"type"] isEqualToString:[NSString stringWithUTF8String:type]] &&
               [[field objectForKey:@"notnull"] intValue] == notnull &&
               (dflt_value?([[field objectForKey:@"dflt_value"] isEqualToString:[NSString stringWithUTF8String:dflt_value]]):
                ([field objectForKey:@"dflt_value"]==NULL)) &&
               [[field objectForKey:@"pk"] intValue] == pk) {
                /*NSLog(@"equal field in database: index[%d]= [%d,%s,%s,%d,%s,%d]",index,
                      cid, name, type, notnull,(dflt_value?dflt_value:"NULL"),pk);*/
            } else {
                NSLog(@"not equal field in database: index[%d]= [%d,%s,%s,%d,%s,%d]",index,
                      cid, name, type, notnull,(dflt_value?dflt_value:"NULL"),pk);
            }
        }
        index++;
    }
    sqlite3_finalize(statement);
    for(;index < [[definition objectForKey:@"fields"] count];index++) {
        NSDictionary* field  = [[definition objectForKey:@"fields"] objectAtIndex:index];sqlite3_stmt *add = nil;
        int cid = [[field objectForKey:@"cid"] intValue];
        const char* name = [[field objectForKey:@"name"] UTF8String];
        const char* type = [[field objectForKey:@"type"] UTF8String];
        int notnull = [[field objectForKey:@"notnull"] intValue];
        const char* dflt_value = [[field objectForKey:@"dflt_value"] UTF8String];
        int pk = [[field objectForKey:@"pk"] intValue];

        NSLog(@"new field for database: index[%d]= [%d,%s,%s,%d,%s,%d]",index,
              cid, name, type, notnull,(dflt_value?dflt_value:"NULL"),pk);
        const char *addsql = [[NSString stringWithFormat:@"alter table %@ add column \"%@\" TEXT %@",
                               [definition objectForKey:@"tablename"],
                               [field objectForKey:@"name"],
                               (notnull==1?@"not null ":@"")
                               ] UTF8String];
        if (sqlite3_prepare_v2(db, addsql, -1, &add , NULL) != SQLITE_OK) {
            NSLog(@"failed to prepare: %s",addsql);
        } else {
            if(SQLITE_DONE == sqlite3_step(add)) {
                NSLog(@"new field was added");
            } else {
                NSLog(@"failed to execute: %s",addsql);
            }
        }
        sqlite3_finalize(add);
    }

    return YES;
}
@end
