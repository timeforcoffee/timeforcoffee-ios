//
//  SHKSearchController.m
//  Smooch
//
//  Created by Mike on 2014-05-06.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKSearchController.h"
#import "SHKUtility.h"
#import "SHKSearchClient.h"
#import "SHKApiClient.h"
#import "SHKSearchFallbackStrategy.h"
#import "SHKSearchEndpointFactory.h"
#import "SHKZendeskSearchResultsFilter.h"
#import "SmoochHelpKit+Private.h"

NSString* const SHKSearchControllerResultsDidChangeNotification = @"SHKSearchControllerResultsDidChangeNotification";
NSString* const SHKSearchStartedNotification = @"SHKSearchStartedNotification";
NSString* const SHKSearchCancelledNotification = @"SHKSearchCancelledNotification";
NSString* const SHKSearchCompleteNotification = @"SHKSearchCompleteNotification";

@interface SHKSearchController()

@property SHKSearchFallbackStrategy* strategy;

@end

@implementation SHKSearchController
@synthesize searchResults = _searchResults;

+(instancetype)searchControllerWithSettings:(SHKSettings *)settings
{
    SHKApiClient* apiClient = [[SHKApiClient alloc] initWithBaseURL:settings.knowledgeBaseURL];
    
    SHKZendeskSearchResultsFilter* filter = [[SHKZendeskSearchResultsFilter alloc] initWithApiClient:apiClient settings:settings];
    [filter loadCategoryMapIfAny];
    
    SHKSearchClient* searchClient = [[SHKSearchClient alloc] initWithApiClient:apiClient filter:filter];
    SHKSearchEndpointFactory* factory = [[SHKSearchEndpointFactory alloc] initWithKnowledgeBaseURL:settings.knowledgeBaseURL];
    SHKSearchFallbackStrategy* strategy = [[SHKSearchFallbackStrategy alloc] initWithSearchClient:searchClient factory:factory];
    
    return [[SHKSearchController alloc] initWithStrategy:strategy];
}

-(instancetype)initWithStrategy:(SHKSearchFallbackStrategy*)strategy
{
    self = [super init];
    if(self){
        _strategy = strategy;
    }
    return self;
}

-(void)search:(NSString *)searchText
{
    self.error = nil;
    
    if(searchText.length == 0){
        [self cancelCurrentRequest];
        self.searchResults = nil;
        return;
    }
    
    [self notify:SHKSearchStartedNotification andSetIndicatorVisible:YES];
    [self.strategy search:searchText withCompletion:^(NSArray *results, NSError *error) {
        if(error){
            self.error = error;
            self.searchResults = nil;
        }else{
            self.searchResults = results;
        }
        [self notify:SHKSearchCompleteNotification andSetIndicatorVisible:NO];
    }];
}

-(void)setSearchResults:(NSArray *)searchResults
{
    _searchResults = searchResults;
    
    SHKEnsureMainThread(^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SHKSearchControllerResultsDidChangeNotification object:self];
    });
}

-(NSArray*)searchResults
{
    return _searchResults;
}

-(SHKSearchResult*)searchResultAtIndex:(NSInteger)index
{
    if (index >= self.searchResults.count) {
        return nil;
    }
    return self.searchResults[index];
}

-(void)cancelCurrentRequest
{
    [self.strategy.searchClient cancelCurrentRequest];
    [self notify:SHKSearchCancelledNotification andSetIndicatorVisible:NO];
}

-(void)notify:(NSString*)name andSetIndicatorVisible:(BOOL)visible
{
    [[NSNotificationCenter defaultCenter] postNotificationName:name object:self];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:visible];
}

@end
