//
//  SHKHelpCenterAjaxEndpoint.m
//  Smooch
//
//  Created by Mike Spensieri on 2014-10-14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKHelpCenterAjaxEndpoint.h"

@implementation SHKHelpCenterAjaxEndpoint

-(NSString*)urlForQuery:(NSString*)query
{
    return [NSString stringWithFormat:@"hc/en-us/search.json?query=%@", query];    
}

-(NSArray*)deserializeResultsJSON:(id)jsonObject
{
    NSString *html = [jsonObject valueForKey:@"html"];
    return [self parseHtmlResponse:html];
}

-(BOOL)failIfHeadIsPresent
{
    return NO;
}

@end
