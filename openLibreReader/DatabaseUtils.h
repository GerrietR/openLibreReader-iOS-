//
//  DatabaseUtil
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

@interface DatabaseUtils : NSObject

+(BOOL) ensureDefinition:(NSDictionary*)definition database:(sqlite3*)db;
@end

