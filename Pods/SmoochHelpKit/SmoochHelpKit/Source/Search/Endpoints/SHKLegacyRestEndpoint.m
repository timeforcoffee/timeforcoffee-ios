//
//  SHKLegacyRestEndpoint.m
//  Smooch
//
//  Created by Mike Spensieri on 2014-10-14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKLegacyRestEndpoint.h"

@implementation SHKLegacyRestEndpoint

-(NSString*)urlForQuery:(NSString*)query
{
    return [NSString stringWithFormat:@"api/v2/portal/search.json?query=%@", query];
}

@end
