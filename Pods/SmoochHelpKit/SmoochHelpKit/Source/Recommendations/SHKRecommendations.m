//
//  SHKRecommendations.m
//  Smooch
//
//  Created by Joel Simpson on 2014-04-15.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKRecommendations.h"
#import "SHKUtility.h"
#import "SmoochHelpKit+Private.h"

NSString* const SHKRecommendationsUpdatedNotification = @"SHKRecommendedArticlesUpdatedNotification";

static NSString* const kBadArticleURL = @"Recommendation URL must contain http:// or https:// and be valid as per NSURL";

@interface SHKRecommendations()

@property (nonatomic) NSArray* defaultRecommendations;
@property (nonatomic) NSString* topRecommendation;

@end

@implementation SHKRecommendations

- (id)init
{
    self = [super init];
    if (self) {
        _topRecommendation = nil;
        _defaultRecommendations = [NSMutableArray new];
    }
    return self;
}

- (void)setTopRecommendation:(NSString *)urlString
{
    if(SHKIsValidZendeskUrl(urlString) || urlString == nil)
    {
        _topRecommendation = urlString;
    }else{
        _topRecommendation = nil;
        NSLog(@"<Smooch: WARNING> Invalid URL passed to setTopRecommendation, it will be ignored: %@. %@", urlString, kBadArticleURL);
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SHKRecommendationsUpdatedNotification object:nil];
}

- (void)setDefaultRecommendations:(NSArray *)urlStrings
{
    NSMutableArray* temp = [urlStrings mutableCopy];
    for (NSString* url in urlStrings)
    {
        if(!SHKIsValidZendeskUrl(url))
        {
            [temp removeObject:url];
            NSLog(@"<Smooch: WARNING> Invalid URL passed to setDefaultRecommendations, it will be ignored: %@. %@", url, kBadArticleURL);
        }
    }
    _defaultRecommendations = temp ?: @[];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SHKRecommendationsUpdatedNotification object:nil];
}

- (NSArray*)recommendationsList
{
    NSMutableArray* activeArticles = [self.defaultRecommendations mutableCopy];
    if(self.topRecommendation)
    {
        [activeArticles insertObject:self.topRecommendation atIndex:0];
    }
    return activeArticles;
}

@end