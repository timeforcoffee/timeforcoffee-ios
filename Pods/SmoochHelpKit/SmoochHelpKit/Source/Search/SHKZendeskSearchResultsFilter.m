//
//  SHKZendeskSearchResultsFilter.m
//  Smooch
//
//  Created by Mike Spensieri on 2014-10-14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKZendeskSearchResultsFilter.h"
#import "SHKSettings+Private.h"
#import "SHKApiClient.h"
#import "SHKSearchResult.h"

static const NSString* kZendeskSectionApiEndpoint = @"api/v2/help_center/sections.json";

@interface SHKZendeskSearchResultsFilter()

@property SHKSettings* sdkSettings;
@property SHKApiClient* apiClient;

@end

@implementation SHKZendeskSearchResultsFilter

-(instancetype)initWithApiClient:(SHKApiClient*)apiClient settings:(SHKSettings *)settings
{
    self = [super init];
    if(self){
        _sdkSettings = settings;
        _apiClient = apiClient;
        _categoryMap = @{};
    }
    return self;
}

-(BOOL)filteringEnabled
{
    return (self.sdkSettings.sectionsToFilter.count > 0) || (self.sdkSettings.categoriesToFilter.count > 0);
}

-(void)loadCategoryMapIfAny
{
    if(self.sdkSettings.categoriesToFilter.count > 0){
        NSString* fullyQualifiedURL = [NSString stringWithFormat:@"%@/%@", self.sdkSettings.knowledgeBaseURL, kZendeskSectionApiEndpoint];
        
        // This is an HTTPS only api
        NSString* httpsURL = [fullyQualifiedURL stringByReplacingOccurrencesOfString:@"http://" withString:@"https://"];
        [self.apiClient GET:httpsURL parameters:nil completion:^(NSURLSessionDataTask *task, NSError *error, id responseObject) {
            if(error){
                NSLog(@"<Smooch: ERROR> Failed to retrieve list of categories from Zendesk - search filtering by category will be disabled. \nError: %@", error);
                self.categoryMap = @{};
            }else{
                self.categoryMap = [self parseSectionApiResponse:responseObject];
            }
        }];
    }
}

-(NSDictionary*)parseSectionApiResponse:(id)response
{
    NSArray* sections = [response valueForKey:@"sections"];
    NSMutableDictionary* mapping = [NSMutableDictionary new];
    for (id object in sections) {
        NSNumber* sectionId = object[@"id"];
        NSNumber* categoryId = object[@"category_id"];
        if (sectionId && categoryId) {
            mapping[sectionId] = categoryId;
        }
    }
    return mapping;
}

- (NSArray*)filterResults:(NSArray*)results
{
    if(!results){
        return nil;
    }
    
    NSMutableArray* mutableResults = [results mutableCopy];
    SHKSearchResultsFilterMode mode = self.sdkSettings.filterMode;
    
    for(SHKSearchResult* result in results){
        if(!result.sectionId){
            continue;
        }
        
        if([self isSectionInFilter:result.sectionId]){
            if(mode == SHKSearchResultIsIn){
                [mutableResults removeObject:result];
            }
        }else{
            if(mode == SHKSearchResultIsNotIn){
                [mutableResults removeObject:result];
            }
        }
    }
    
    return [mutableResults copy];
}

-(BOOL)isSectionInFilter:(NSNumber*)sectionId
{
    BOOL isSectionInFilter = [self.sdkSettings.sectionsToFilter containsObject:sectionId];
    
    NSString* categoryId = self.categoryMap[sectionId];
    BOOL isCategoryInFilter = categoryId && [self.sdkSettings.categoriesToFilter containsObject:categoryId];
    
    return isSectionInFilter || isCategoryInFilter;
}

@end
