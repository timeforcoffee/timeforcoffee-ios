//
//  SHKZendeskSearchResultsFilter.h
//  Smooch
//
//  Created by Mike Spensieri on 2014-10-14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <Foundation/Foundation.h>
@class SHKSettings;
@class SHKApiClient;

@interface SHKZendeskSearchResultsFilter : NSObject

-(instancetype)initWithApiClient:(SHKApiClient*)apiClient settings:(SHKSettings *)settings;

-(void)loadCategoryMapIfAny;

-(BOOL)filteringEnabled;
-(NSArray*)filterResults:(NSArray*)results;

@property NSDictionary* categoryMap;

@end
