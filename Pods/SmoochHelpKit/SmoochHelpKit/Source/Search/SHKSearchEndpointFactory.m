//
//  SHKSearchEndpointFactory.m
//  Smooch
//
//  Created by Mike Spensieri on 2014-10-14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKSearchEndpointFactory.h"
#import "SHKLegacyAjaxEndpoint.h"
#import "SHKLegacyRestEndpoint.h"
#import "SHKHelpCenterAjaxEndpoint.h"
#import "SHKHelpCenterRestEndpoint.h"
#import "SHKZendeskSearchResultsFilter.h"

@interface SHKSearchEndpointFactory()

@property NSString* knowledgeBaseURL;

@end

@implementation SHKSearchEndpointFactory

-(instancetype)initWithKnowledgeBaseURL:(NSString*)knowledgeBaseURL
{
    self = [super init];
    if(self){
        _knowledgeBaseURL = knowledgeBaseURL;
    }
    return self;
}

-(id<SHKSearchEndpoint>)objectForEndpoint:(SHKZendeskApiEndpoint)endpoint
{
    switch(endpoint){
        case SHKZendeskApiAjaxEndpoint:
            return [[SHKHelpCenterAjaxEndpoint alloc] initWithKnowledgeBaseURL:self.knowledgeBaseURL];
        case SHKZendeskApiAjaxLegacyEndpoint:
            return [[SHKLegacyAjaxEndpoint alloc] initWithKnowledgeBaseURL:self.knowledgeBaseURL];
        case SHKZendeskApiHelpCenterEndpoint:
            return [[SHKHelpCenterRestEndpoint alloc] init];
        case SHKZendeskApiLegacyRestEndpoint:
            return [[SHKLegacyRestEndpoint alloc] init];
        default:
            return nil;
    }
}

@end
