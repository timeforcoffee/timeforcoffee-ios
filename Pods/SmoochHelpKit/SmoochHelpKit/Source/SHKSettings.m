//
//  SHKSettings.m
//  Smooch
//
//  Created by Mike Spensieri on 2015-10-11.
//  Copyright © 2015 Smooch Technologies. All rights reserved.
//

#import "SHKSettings.h"
#import "SHKSettings+Private.h"

@interface SHKSettings()

@property NSArray* categoriesToFilter;
@property NSArray* sectionsToFilter;
@property SHKSearchResultsFilterMode filterMode;

@end

@implementation SHKSettings

+(instancetype)settingsWithAppToken:(NSString*)appToken
{
    SHKSettings* settings = [[SHKSettings alloc] init];
    settings.appToken = appToken;
    return settings;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _enableAppWideGesture = YES;
        _enableGestureHintOnFirstLaunch = YES;
        _enableZendeskArticleRestyling = YES;
        _categoriesToFilter = @[];
        _sectionsToFilter = @[];
        _filterMode = SHKSearchResultIsIn;
    }
    return self;
}

-(NSArray*)refineIdArray:(NSArray*)ids
{
    NSMutableArray* result = [NSMutableArray new];
    for(id object in ids){
        NSNumber* objectId = nil;
        
        if([object isKindOfClass:[NSString class]]){
            objectId = @([object integerValue]);
        }else if([object isKindOfClass:[NSNumber class]]){
            objectId = object;
        }
        
        if(objectId != nil && [objectId integerValue] > 0){
            [result addObject:objectId];
        }else{
            NSLog(@"<Smooch: WARNING> Invalid section or category id given, it will be ignored: \"%@\". Ids must be numeric and positive. ie: @123", object);
        }
    }
    return result;
}

-(void)excludeSearchResultsIf:(SHKSearchResultsFilterMode)filterMode categories:(NSArray *)categories sections:(NSArray *)sections
{
    if(self.categoriesToFilter.count > 0 || self.sectionsToFilter.count > 0){
        NSLog(@"<Smooch: ERROR> Search results filtering may only be configured once, and should be done at init time. New filtering options will be ignored");
        return;
    }
    
    if(filterMode == SHKSearchResultIsIn || filterMode == SHKSearchResultIsNotIn){
        self.filterMode = filterMode;
    }else{
        NSLog(@"<Smooch: ERROR> Invalid search results filter mode - no filtering will be applied.");
        return;
    }
    
    if(categories.count == 0 && sections.count == 0){
        NSLog(@"<Smooch: WARNING> Category and sections arrays empty - no filtering will be applied.");
        return;
    }
    
    NSArray* refinedCategories = [self refineIdArray:categories];
    NSArray* refinedSections = [self refineIdArray:sections];
    
    if(refinedCategories.count == 0 && refinedSections.count == 0){
        NSLog(@"<Smooch: ERROR> No valid section or category ids were given - no filtering will be applied.");
        return;
    }
    
    self.categoriesToFilter = refinedCategories;
    self.sectionsToFilter = refinedSections;
}

-(void)setKnowledgeBaseURL:(NSString *)knowledgeBaseURL
{
    if(_knowledgeBaseURL){
        NSLog(@"<Smooch: ERROR> Knowledge base URL may only be set once, and should be set at init time. New value \"%@\" will be ignored", knowledgeBaseURL);
    }else{
        _knowledgeBaseURL = [knowledgeBaseURL copy];
    }
}

@end
