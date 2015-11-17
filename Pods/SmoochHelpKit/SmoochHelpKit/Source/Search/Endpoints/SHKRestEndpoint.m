//
//  SHKRestEndpoint.m
//  Smooch
//
//  Created by Mike Spensieri on 2014-10-14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKRestEndpoint.h"
#import "SHKSearchResult.h"

@implementation SHKRestEndpoint

-(NSString*)urlForQuery:(NSString *)query
{
    NSAssert(FALSE, @"Override this method!");
    return nil;
}

-(NSArray*)deserializeResultsJSON:(id)jsonObject
{
    NSArray* jsonArray = [jsonObject valueForKeyPath:@"results"];
    
    NSMutableArray* results = [NSMutableArray new];
    
    for(NSDictionary* jsonResult in jsonArray){
        [results addObject:[[SHKSearchResult alloc] initWithDictionary:jsonResult]];
    }
    
    return [results copy];
}

@end
