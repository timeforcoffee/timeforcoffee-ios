//
//  SHKRecommendationsManager.m
//  Smooch
//
//  Created by Michael Spensieri on 4/11/14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKRecommendationsManager.h"
#import "SHKNavigationViewController.h"
#import "SHKRecommendationPreviewView.h"
#import "SHKVerticalProgressView.h"
#import "SHKRecommendations.h"
#import "SHKStateMachine.h"
#import "SHKUtility.h"
#import "SHKImageLoader.h"

static const int        kPaddingBetweenArticles = 50;
static const CGFloat    kAnimationDurationSlideToTappedArticle = 0.5;

@interface SHKRecommendationsManager()

@property(weak) SHKNavigationViewController* navigationController;
@property SHKRecommendations* recommendations;
@property(readonly) NSInteger firstSwipeViewIndex;
@property(readonly) NSInteger lastSwipeViewIndex;

@end

@implementation SHKRecommendationsManager

- (instancetype)initWithImageLoader:(SHKImageLoader*)imageLoader navigationController:(SHKNavigationViewController*)controller andRecommendations:(SHKRecommendations*)recommendations
{
    self = [super init];
    if (self) {
        _imageLoader = imageLoader;
        _navigationController = controller;
        _recommendations = recommendations;
    }
    return self;
}

- (NSInteger)numberOfRecommendationsInSwipeView
{
    return self.recommendations.recommendationsList.count;
}

- (NSInteger)numberOfItemsInSwipeView:(SHKSwipeView *)swipeView
{
    // Number of recommendations + two blank spaces at the beginning + one blank space at the end
    return [self numberOfRecommendationsInSwipeView] + 3;
}

- (UIView *)swipeView:(SHKSwipeView *)swipeView viewForItemAtIndex:(NSInteger)index reusingView:(UIView *)viewToReuse
{
    UIView* containerView = [UIView new];
    
    if([self isIndexOfBlankView:index]){
        return containerView;
    }
    
    SHKRecommendationPreviewView* preview = [SHKRecommendationPreviewView new];
    
    CGSize screenSize = SHKOrientedScreenSize();
    preview.frame = CGRectMake(kPaddingBetweenArticles / 2, 0, screenSize.width, screenSize.height);
    
    [containerView addSubview:preview];
    
    if(self.shouldTakeScreenshots){
        NSInteger arrayIndex = [self arrayIndexOfSwipeViewItem:index];
        
        NSString* url = self.recommendations.recommendationsList[arrayIndex];
        
        [preview.loadingBar start];
        [self.imageLoader loadImageForUrl:url withCompletion:^(UIImage *image) {
            if(image == nil){
                [preview markAsFailed];
            }else{
                [preview crossfadeToImage:image];
            }
            
            if(arrayIndex == 0 && swipeView.currentItemIndex == self.firstSwipeViewIndex){
                [swipeView scrollToItemAtIndex:1 duration:kAnimationDurationSlideInFirstArticle];
            }
            swipeView.scrollEnabled = YES;
            self.didLoadPreview = YES;
            [preview.loadingBar finish];
        }];
    }
    
    return containerView;
}

-(void)swipeView:(SHKSwipeView *)swipeView didSelectItemAtIndex:(NSInteger)tappedIndex
{
    if(tappedIndex == self.firstSwipeViewIndex || tappedIndex == self.lastSwipeViewIndex){
        return;
    }

    if(tappedIndex == [self indexOfMiddleItemInSwipeView:swipeView]){
        if(tappedIndex == 1){
            // User tapped on the app, close Smooch
            [[SHKStateMachine sharedInstance] transitionToState:SmoochStateInactive];
            return;
        }
        
        NSString* url = (self.recommendations.recommendationsList)[[self arrayIndexOfSwipeViewItem:tappedIndex]];
        [self.navigationController showArticle:url];
    }else if(swipeView.scrollEnabled){
        // Tapped a view on the side, scroll to it
        [swipeView scrollToItemAtIndex:tappedIndex - 1 duration:kAnimationDurationSlideToTappedArticle];
    }
}

-(void)swipeViewDidScroll:(SHKSwipeView *)swipeView
{
    if([self.delegate respondsToSelector:@selector(recommendationsManager:didScrollToOffset:)]){
        [self.delegate recommendationsManager:self didScrollToOffset:swipeView.scrollOffset];
    }
}

-(void)swipeViewCurrentItemIndexDidChange:(SHKSwipeView *)swipeView
{
    if([self.delegate respondsToSelector:@selector(recommendationsManager:didChangeIndex:)]){
        [self.delegate recommendationsManager:self didChangeIndex:swipeView.currentItemIndex];
    }
}

- (CGSize)swipeViewItemSize:(SHKSwipeView *)swipeView
{
    CGSize screenSize = SHKOrientedScreenSize();
    return CGSizeMake(screenSize.width + kPaddingBetweenArticles, screenSize.height);
}

-(void)clearImageCache
{
    [self.imageLoader clearImageCache];
}

-(NSInteger)arrayIndexOfSwipeViewItem:(NSInteger)itemIndex
{
    // Subtract the two invisible indices to return the index in the array
    return itemIndex - 2;
}

-(NSInteger)indexOfMiddleItemInSwipeView:(SHKSwipeView*)swipeView
{
    // currentItemIndex represents the left hand side, +1 is the index of the view in the middle
    return swipeView.currentItemIndex + 1;
}

-(BOOL)isIndexOfBlankView:(NSInteger)index
{
    return index <= 1 || index == self.lastSwipeViewIndex;
}

-(NSInteger)firstSwipeViewIndex
{
    return 0;
}

-(NSInteger)lastSwipeViewIndex
{
    return [self numberOfRecommendationsInSwipeView] + 2;
}

@end
