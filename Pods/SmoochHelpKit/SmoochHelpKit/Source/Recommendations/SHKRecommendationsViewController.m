//
//  SHKRecommendationsViewController.m
//  Smooch
//
//  Created by Joel Simpson on 2014-04-17.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKRecommendationsViewController.h"
#import "SHKRecommendationsManager.h"
#import "SHKArticleScreenshotWebView.h"
#import "SHKNavigationViewController.h"
#import "SHKSwipeView.h"
#import "SHKUtility.h"
#import "SHKMessagesButtonView.h"
#import "SHKLocalization.h"
#import "SmoochHelpKit+Private.h"
#import "SHKRecommendations.h"
#import "SHKWindow.h"
#import "SHKStateMachine.h"
#import "SHKOverlayWindow.h"
#import "SHKOffsetManager.h"
#import "SHKTransition.h"
#import "SHKAppColorExtractor.h"

static const CGFloat kLabelOffsetPercentageiPad = 0.33;
static const CGFloat kLabelOffsetPercentage3_5InchScreen = 0.10;
static const CGFloat kLabelOffsetPercentage4InchScreen = 0.15;
static const CGFloat kLabelFadeAnimationDuration = 0.2;

NSString* const SHKRecommendationsViewControllerReachedEndOfRecommandation = @"SHKArticleViewControllerReachedEndOfRecommandation";
NSString* const SHKRecommendationsViewControllerReachedSecondToLastRecommendation = @"SHKRecommendationsViewControllerReachedSecondToLast";

@interface SHKRecommendationsViewController()

@property UILabel* headerLabel;
@property UILabel* indexLabel;
@property BOOL needsUpdate;
@property UIInterfaceOrientation lastOrientationOfSwipeView;
@property SHKSwipeView* swipeView;
@property BOOL shouldTriggerReachedEndOfRecommandation;
@property(readonly) BOOL inNavigationController;
@property SHKArticleScreenshotWebView* screenshotWebView;

@end

@implementation SHKRecommendationsViewController

-(BOOL)inNavigationController
{
    return [self.parentViewController isKindOfClass:[UINavigationController class]];
}

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    self.lastOrientationOfSwipeView = [UIApplication sharedApplication].statusBarOrientation;
    self.needsUpdate = YES;
    
    [self initRecommendationsManager];
    [self initSwipeView];
    [self initIndexLabel];
    
    if(self.inNavigationController){
        [self initNavigationItem];
    }else{
        [self initHeaderLabel];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onRecommendationsUpdated) name:SHKRecommendationsUpdatedNotification object:nil];
}

-(void)initNavigationItem
{
    UILabel* titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, CGFLOAT_MAX, CGFLOAT_MAX)];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.font = [UIFont systemFontOfSize:16];
    titleLabel.text = [SHKLocalization localizedStringForKey:@"Recommended For You"];
    [titleLabel sizeToFit];
    
    self.navigationItem.titleView = titleLabel;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[SHKLocalization localizedStringForKey:@"Close"]
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(onClose)];
}

-(void)onClose
{
    [SmoochHelpKit close];
}

-(void)initRecommendationsManager
{
    UINavigationController* navController = self.navigationController ?: self.parentViewController.navigationController;
    
    self.screenshotWebView = [[SHKArticleScreenshotWebView alloc] initWithFrame:self.view.bounds];
    SHKImageLoader* imageLoader = [[SHKImageLoader alloc] initWithStrategy:self.screenshotWebView];
    
    self.recommendationsManager = [[SHKRecommendationsManager alloc] initWithImageLoader:imageLoader
                                                                     navigationController:(SHKNavigationViewController*)navController
                                                                   andRecommendations:[SmoochHelpKit getRecommendations]];
    self.recommendationsManager.shouldTakeScreenshots = NO;
    self.recommendationsManager.delegate = self;
}

-(void)initSwipeView
{
    self.swipeView = [[SHKSwipeView alloc] init];
    self.swipeView.clipsToBounds = NO;
    self.swipeView.delegate = self.recommendationsManager;
    self.swipeView.dataSource = self.recommendationsManager;
    self.swipeView.scrollEnabled = NO;
    
    [self.view addSubview:self.swipeView];
}

-(void)initHeaderLabel
{
    self.headerLabel = [self newTextLabel];
    self.headerLabel.text = [SHKLocalization localizedStringForKey:@"Recommended For You"];
    
    [self.view addSubview:self.headerLabel];
}

-(void)initIndexLabel
{
    self.indexLabel = [self newTextLabel];
    
    [self.view addSubview:self.indexLabel];
}

-(UILabel*)newTextLabel
{
    UILabel* label = [[UILabel alloc] init];
    label.textColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.backgroundColor = [UIColor clearColor];
    label.alpha = 0;
    
    int fontSize = SHKIsTallScreenDevice() ? 16 : 13;
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
        fontSize = 20;
    }
    label.font = [UIFont systemFontOfSize:fontSize];
    
    return label;
}

-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    CGRect labelFrame = CGRectMake(0, 0, self.view.bounds.size.width, 30);
    self.headerLabel.frame = labelFrame;
    self.headerLabel.center = [self getHeaderCenterPoint];
    
    self.indexLabel.frame = labelFrame;
    self.indexLabel.center = [self getIndexLabelCenterPoint];
    
    if(SHKIsStatusBarTall()){
        self.headerLabel.hidden = YES;
        self.indexLabel.hidden = YES;
    }else{
        self.headerLabel.hidden = NO;
        self.indexLabel.hidden = NO;
    }
    
    self.swipeView.transform = CGAffineTransformIdentity;
    CGSize itemSize = [self.recommendationsManager swipeViewItemSize:self.swipeView];
    self.swipeView.frame = CGRectMake(0, 0, itemSize.width * 3, itemSize.height);
    
    self.swipeView.center = CGPointMake(self.view.center.x, self.view.center.y);

    self.screenshotWebView.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.swipeView.frame.size.height);
    
    CGFloat scale = [SHKOverlayWindow getMaxScaleDownFactor];
    self.swipeView.transform =  CGAffineTransformScale(CGAffineTransformIdentity, scale, scale);
    
    if(self.lastOrientationOfSwipeView != [UIApplication sharedApplication].statusBarOrientation){
        self.lastOrientationOfSwipeView = [UIApplication sharedApplication].statusBarOrientation;
        [self setNeedsSwipeViewUpdate];
    }
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSmoochBecameActive:) name:SHKStateMachineDidEnterActiveStateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSmoochBecameInActive) name:SHKStateMachineDidEnterInactiveStateNotification object:nil];
    
    if(self.needsUpdate && self.recommendationsManager.shouldTakeScreenshots){
        self.needsUpdate = NO;
        [self refreshSwipeView];
    }
    
    if(self.swipeView.currentItemIndex == 0){
        UILabel* titleLabel = (UILabel*)self.navigationItem.titleView;
        titleLabel.alpha = 0;
    }
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SHKStateMachineDidEnterActiveStateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SHKStateMachineDidEnterInactiveStateNotification object:nil];
}

-(CGFloat)getLabelOffsetPercentage
{
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
        return kLabelOffsetPercentageiPad;
    }
    
    if(SHKIsTallScreenDevice()){
        return kLabelOffsetPercentage4InchScreen;
    }
    
    return kLabelOffsetPercentage3_5InchScreen;
}

-(CGPoint)getHeaderCenterPoint
{
    CGFloat swipeViewOriginY = self.view.bounds.size.height * ((1 - [SHKOverlayWindow getMaxScaleDownFactor]) / 2);
    CGRect searchBarFrame = [self.view convertRect:self.parentViewController.navigationItem.titleView.frame fromView:self.parentViewController.navigationController.view];
    
    CGFloat yOffset = self.headerLabel.alpha == 0 ? 15 : 0;
    CGFloat midPointBetweenSearchBarAndSwipeView = CGRectGetMaxY(searchBarFrame) + ((swipeViewOriginY - CGRectGetMaxY(searchBarFrame)) / 2);
    
    // Offset the label by a percentage of the distance, so it is a bit closer to the swipe view
    CGFloat positionAdjustment = (swipeViewOriginY - midPointBetweenSearchBarAndSwipeView) * [self getLabelOffsetPercentage];
    
    return CGPointMake(self.view.center.x, midPointBetweenSearchBarAndSwipeView + yOffset + positionAdjustment);
}

-(CGPoint)getIndexLabelCenterPoint
{
    CGFloat swipeViewMaxY = self.view.bounds.size.height - (self.view.bounds.size.height * ((1 - [SHKOverlayWindow getMaxScaleDownFactor]) / 2));
    CGFloat messagesButtonMinY = self.view.bounds.size.height - [SHKMessagesButtonView getButtonMinYCoordinate];
    
    CGFloat midPointBetweenSwipeViewAndMessagesButton = swipeViewMaxY + ((messagesButtonMinY - swipeViewMaxY) / 2);
    
    // Offset the label by a percentage of the distance, so it is a bit closer to the swipe view
    CGFloat positionAdjustment = (midPointBetweenSwipeViewAndMessagesButton - swipeViewMaxY) * [self getLabelOffsetPercentage];
    
    return CGPointMake(self.view.center.x, midPointBetweenSwipeViewAndMessagesButton - positionAdjustment);
}

- (void)fadeInLabels
{
    [self animateLabelsToAlpha:1.0 duration:kLabelFadeAnimationDuration];
}

- (void)fadeOutLabels
{
    [self animateLabelsToAlpha:0.0 duration:kLabelFadeAnimationDuration];
}

-(void)animateLabelsToAlpha:(CGFloat)finalAlpha duration:(CGFloat)duration
{
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.indexLabel.alpha = finalAlpha;
        self.headerLabel.alpha = finalAlpha;
        self.headerLabel.center = [self getHeaderCenterPoint];
        self.navigationItem.titleView.alpha = finalAlpha;
    } completion:nil];
}

-(void)onRecommendationsUpdated
{
    [self setNeedsSwipeViewUpdate];
}

-(void)onSmoochBecameActive:(NSNotification*)notification
{
    self.recommendationsManager.shouldTakeScreenshots = YES;
    
    @synchronized(self) {
        if (self.needsUpdate) {
            self.needsUpdate = NO;
            [self refreshSwipeView];
        } else {
            if ([self.recommendationsManager numberOfRecommendationsInSwipeView] > 0) {
                SHKStateMachine* stateMachine = notification.object;
                
                if (stateMachine.transition.sourceState == SmoochStateInactive || stateMachine.transition.sourceState == SmoochStateSemiActive) {
                    [self.swipeView scrollToItemAtIndex:1 duration:kAnimationDurationSlideInFirstArticle];
                } else if(self.swipeView.currentItemIndex > 0) {
                    [self fadeInLabels];
                }
                self.swipeView.scrollEnabled = YES;
            }
        }
    }
}

-(void)onSmoochBecameInActive
{
    [self.swipeView scrollToItemAtIndex:0 duration:0];
}

-(void)resetSwipeViewToStart
{
    self.swipeView.scrollEnabled = NO;
    [self animateLabelsToAlpha:0.0 duration:0];
}

-(void)setNeedsSwipeViewUpdate
{
    @synchronized(self){
        if(self.view.window == nil || self.view.window.hidden){
            self.needsUpdate = YES;
        }else{
            [self refreshSwipeView];
        }
    }
}

-(void)refreshSwipeView
{
    [self.recommendationsManager clearImageCache];
    [self.swipeView reloadData];
}

-(void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    self.view.alpha = 0.0;
}

-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    
    // For some reason this is required here or the placement is wrong after a rotation
    self.headerLabel.center = [self getHeaderCenterPoint];
    
    [self setNeedsSwipeViewUpdate];
    
    self.view.alpha = 1.0;
}

#pragma mark - SHKRecommendedArticleManagerDelegate

-(void)recommendationsManager:(SHKRecommendationsManager *)manager didChangeIndex:(NSInteger)newIndex
{
    if([manager numberOfRecommendationsInSwipeView] == 0){
        return;
    }
    
    if(newIndex > 0)
    {
        if(self.indexLabel.alpha != 1.0){
            [self fadeInLabels];
        }
        
        long numberOfArticles = [manager numberOfRecommendationsInSwipeView];
        
        // There's an invisible view at the end, we don't want to include an index for that one.
        long indexToShow = MIN(newIndex, numberOfArticles);
        
        self.indexLabel.text = [NSString stringWithFormat:@"%ld / %ld", (long)indexToShow, (long)numberOfArticles];
        
        [SHKStateMachine sharedInstance].offsetManager.activeStateSnapPercentage = SHKOffsetManagerMiniaturePercentage;
    }else{
        if(self.indexLabel.alpha != 0.0){
            [self fadeOutLabels];
        }
        
        [SHKStateMachine sharedInstance].offsetManager.activeStateSnapPercentage = SHKOffsetManagerActivePercentage;
    }
    if(newIndex == ([manager numberOfRecommendationsInSwipeView] -1)){
        [[NSNotificationCenter defaultCenter] postNotificationName:SHKRecommendationsViewControllerReachedSecondToLastRecommendation object:nil];
    }
}

-(void)recommendationsManager:(SHKRecommendationsManager *)manager didScrollToOffset:(CGFloat)offset
{
    if([manager numberOfRecommendationsInSwipeView] == 0){
        return;
    }
    
    CGFloat percentComplete = 0.0;
    
    // Zoom out the app as we scroll, if there are recommendations to show
    if(offset > 0.1){
        percentComplete = MIN(1.0, (offset - 0.1) / 0.15);
    }
    
    if([SHKStateMachine currentState] == SmoochStateActive){
        [[SHKStateMachine sharedInstance].offsetManager animateToPercentage:SHKOffsetManagerActivePercentage + percentComplete isDragging:YES withCompletion:nil];
    }
    
    if((offset - [manager numberOfRecommendationsInSwipeView]) > 0.20f && _shouldTriggerReachedEndOfRecommandation){
        _shouldTriggerReachedEndOfRecommandation = NO;
        [[NSNotificationCenter defaultCenter] postNotificationName:SHKRecommendationsViewControllerReachedEndOfRecommandation object:nil];
    }
    
    // once we are exactly scrolled to the last recommendation when can start notifying (again)
    if(offset <= [manager numberOfRecommendationsInSwipeView]){
        _shouldTriggerReachedEndOfRecommandation = YES;
    }
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
