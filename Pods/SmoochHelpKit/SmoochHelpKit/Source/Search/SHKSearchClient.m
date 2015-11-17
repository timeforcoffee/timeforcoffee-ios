//
//  SHKSearchClient.m
//  Smooch
//
//  Created by Mike Spensieri on 2014-10-14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SHKSearchClient.h"
#import "SHKApiClient.h"
#import "SHKSearchEndpoint.h"
#import "SHKZendeskSearchResultsFilter.h"

static NSString* const kIPhoneUserAgent = @"Mozilla/5.0 (iPhone; CPU iPhone OS 7_0 like Mac OS X) AppleWebKit/537.51.1 (KHTML, like Gecko) Version/7.0 Mobile/11A465 Safari/9537.53";

@interface SHKSearchClient()

@property SHKApiClient* apiClient;
@property NSURLSessionTask* lastRequest;
@property SHKZendeskSearchResultsFilter* filter;

@end

@implementation SHKSearchClient

-(instancetype)initWithApiClient:(SHKApiClient *)apiClient filter:(SHKZendeskSearchResultsFilter *)filter
{
    self = [super init];
    if(self){
        _apiClient = apiClient;
        _filter = filter;
    }
    return self;
}

-(void)dealloc
{
    [self.lastRequest cancel];
}

-(void)search:(NSString *)query withEndpoint:(id<SHKSearchEndpoint>)endpoint withCompletion:(void (^)(NSArray *results, NSError *error))completion
{
    [self cancelCurrentRequest];
    
    // Set user agent to iPhone -- ajax endpoints do not allow queries from iPad
    [self.apiClient setValue:kIPhoneUserAgent forHTTPHeaderField:@"User-Agent"];
    
    self.apiClient.expectJSONResponse = [endpoint respondsToSelector:@selector(deserializeResultsJSON:)];
    
    NSString *encodedQuery = [query stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *path = [endpoint urlForQuery:encodedQuery];
    
    self.lastRequest = [self.apiClient GET:path parameters:nil completion:^(NSURLSessionDataTask *task, NSError *error, id responseObject) {
        if(error){
            BOOL is400 = [(NSHTTPURLResponse*)task.response statusCode] == 400;
            BOOL isEmptyQuery = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length == 0;
            
            if(is400 && isEmptyQuery){
                // HelpKit endpoint returns 400 for empty query, treat it as no results found
                if(completion){
                    completion(@[], nil);
                }
            }else{
                [self searchCompletedWithError:error completion:completion];
            }
        }else{
            [self searchCompletedWithResponseObject:responseObject endpoint:endpoint completion:completion];
        }
    }];
}

-(void)searchCompletedWithError:(NSError*)error completion:(void (^)(NSArray *results, NSError *error))completion
{
    if (error.code == NSURLErrorCancelled){
        return;
    }
    
    if (completion){
        completion(nil, error);
    }
}

-(void)searchCompletedWithResponseObject:(id)responseObject endpoint:(id<SHKSearchEndpoint>)endpoint completion:(void (^)(NSArray *results, NSError *error))completion
{
    NSArray* results;
    if([endpoint respondsToSelector:@selector(deserializeResultsJSON:)]){
        results = [endpoint deserializeResultsJSON:responseObject];
    }else if([endpoint respondsToSelector:@selector(deserializeResultsData:)]){
        results = [endpoint deserializeResultsData:responseObject];
    }
    
    if(self.filteringEnabled){
        results = [self.filter filterResults:results];
    }
    
    if (completion){
        if(results){
            completion(results, nil);
        }else{
            NSError* deserializationError = [NSError new];
            completion(nil, deserializationError);
        }
    }
}

-(void)cancelCurrentRequest
{
    [self.lastRequest cancel];
    self.lastRequest = nil;
}

-(BOOL)filteringEnabled
{
    return [self.filter filteringEnabled];
}

@end
