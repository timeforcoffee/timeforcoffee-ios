//
//  SHKHelpCenterRestEndpoint.m
//  Smooch
//
//  Created by Mike Spensieri on 2014-10-14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKHelpCenterRestEndpoint.h"

@implementation SHKHelpCenterRestEndpoint

-(NSString*)urlForQuery:(NSString*)query
{
    return [NSString stringWithFormat:@"api/v2/help_center/articles/search.json?query=%@", query];
}

@end
