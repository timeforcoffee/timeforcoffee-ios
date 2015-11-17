//
//  SHKSearchEndpointFactory.h
//  Smooch
//
//  Created by Mike Spensieri on 2014-10-14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <Foundation/Foundation.h>
@protocol SHKSearchEndpoint;
@class SHKSearchResult;

typedef NS_ENUM(NSUInteger, SHKZendeskApiEndpoint) {
    SHKZendeskApiUndetermined,
    SHKZendeskApiAjaxEndpoint,
    SHKZendeskApiAjaxLegacyEndpoint,
    SHKZendeskApiHelpCenterEndpoint,
    SHKZendeskApiLegacyRestEndpoint
};

@interface SHKSearchEndpointFactory : NSObject

-(instancetype)initWithKnowledgeBaseURL:(NSString*)knowledgeBaseURL;

-(id<SHKSearchEndpoint>)objectForEndpoint:(SHKZendeskApiEndpoint)endpoint;

@end