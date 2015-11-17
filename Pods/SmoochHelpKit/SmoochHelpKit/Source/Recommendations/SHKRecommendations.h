//
//  SHKRecommendations.h
//  Smooch
//
//  Created by Joel Simpson on 2014-04-15.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* const SHKRecommendationsUpdatedNotification;

@interface SHKRecommendations : NSObject

-(void)setTopRecommendation:(NSString *)urlString;
-(void)setDefaultRecommendations:(NSArray *)urlStrings;

@property(readonly) NSArray* recommendationsList;

@end
