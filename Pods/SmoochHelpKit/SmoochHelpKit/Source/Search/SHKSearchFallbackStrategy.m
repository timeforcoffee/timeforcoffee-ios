//
//  SHKSearchFallbackStrategy.m
//  Smooch
//
//  Created by Mike Spensieri on 2014-10-14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKSearchFallbackStrategy.h"
#import "SHKSearchClient.h"
#import "SHKSearchEndpointFactory.h"

@interface SHKSearchFallbackStrategy()

@property SHKSearchEndpointFactory* factory;

@end

@implementation SHKSearchFallbackStrategy

-(instancetype)initWithSearchClient:(SHKSearchClient *)client factory:(SHKSearchEndpointFactory*)factory
{
    self = [super init];
    if (self) {
        _searchClient = client;
        _factory = factory;
        _apiEndpoint = SHKZendeskApiUndetermined;
    }
    return self;
}

-(void)search:(NSString *)query withCompletion:(void (^)(NSArray *, NSError *))completion
{
    if(self.apiEndpoint == SHKZendeskApiUndetermined){
        if(self.searchClient.filteringEnabled){
            self.apiEndpoint = SHKZendeskApiHelpCenterEndpoint;
        }else{
            self.apiEndpoint = SHKZendeskApiAjaxEndpoint;
        }
    }
    id<SHKSearchEndpoint> endpoint = [self.factory objectForEndpoint:self.apiEndpoint];
    
    [self.searchClient search:query withEndpoint:endpoint withCompletion:^(NSArray *results, NSError *error) {
        if (error) {
            [self onSearchError:error query:query completion:completion];
        } else if (completion){
            completion(results, nil);
        }
    }];
}

-(void)onSearchError:(NSError*)error query:(NSString*)query completion:(void (^)(NSArray *, NSError *))completion
{
    if(error.code == NSURLErrorNotConnectedToInternet || error.code == NSURLErrorNetworkConnectionLost){
        // Don't perform fallback, there was no internet
        if(completion){
            completion(nil, error);
        }
        return;
    }
    
    BOOL shouldFallback = self.apiEndpoint < SHKZendeskApiLegacyRestEndpoint;
    if (shouldFallback){
         self.apiEndpoint++;
        [self search:query withCompletion:completion];
    } else if (completion) {
        completion(nil, error);
    }
}

@end
