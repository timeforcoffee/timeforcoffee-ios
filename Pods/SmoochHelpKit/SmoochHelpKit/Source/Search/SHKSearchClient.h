//
//  SHKSearchClient.h
//  Smooch
//
//  Created by Mike Spensieri on 2014-10-14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <Foundation/Foundation.h>
@class SHKApiClient;
@protocol SHKSearchEndpoint;
@class SHKZendeskSearchResultsFilter;

@interface SHKSearchClient : NSObject

-(instancetype)initWithApiClient:(SHKApiClient*)apiClient filter:(SHKZendeskSearchResultsFilter *)filter;

-(void) search:(NSString*)query withEndpoint:(id<SHKSearchEndpoint>)endpoint withCompletion:(void (^)(NSArray *results, NSError *error))completion;
-(void) cancelCurrentRequest;

@property(readonly) BOOL filteringEnabled;

@end
