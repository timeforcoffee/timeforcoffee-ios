//
//  SHKRecommendationsManager.h
//  Smooch
//
//  Created by Michael Spensieri on 4/11/14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SHKSwipeView.h"
@class SHKImageLoader;
@class SHKNavigationViewController;
@class SHKRecommendations;

static const CGFloat    kAnimationDurationSlideInFirstArticle = 1.0;

@protocol SHKRecommendationsManagerDelegate;

@interface SHKRecommendationsManager : NSObject < SHKSwipeViewDataSource, SHKSwipeViewDelegate >

-(instancetype)initWithImageLoader:(SHKImageLoader*)imageLoader navigationController:(SHKNavigationViewController*)controller andRecommendations:(SHKRecommendations*)recommendations;
@property (NS_NONATOMIC_IOSONLY, readonly) NSInteger numberOfRecommendationsInSwipeView;
-(void)clearImageCache;
-(BOOL)didLoadPreview;

@property BOOL didLoadPreview;
@property BOOL shouldTakeScreenshots;
@property(weak) id<SHKRecommendationsManagerDelegate> delegate;
@property SHKImageLoader* imageLoader;

@end

@protocol SHKRecommendationsManagerDelegate <NSObject>

-(void)recommendationsManager:(SHKRecommendationsManager*)manager didChangeIndex:(NSInteger)newIndex;
-(void)recommendationsManager:(SHKRecommendationsManager*)manager didScrollToOffset:(CGFloat)offset;

@end
