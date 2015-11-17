//
//  SHKLegacyAjaxEndpoint.m
//  Smooch
//
//  Created by Mike Spensieri on 2014-10-14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKLegacyAjaxEndpoint.h"

@implementation SHKLegacyAjaxEndpoint

-(NSString*)urlForQuery:(NSString*)query
{
    return [NSString stringWithFormat:@"categories/search?is_mobile=true&query=%@", query];
}

-(NSArray*)deserializeResultsData:(NSData *)responseData
{
    NSString *html = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    return [self parseHtmlResponse:html];
}

@end
