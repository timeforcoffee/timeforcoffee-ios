//
//  SHKNavigationViewController.m
//  Smooch
//
//  Created by Michael Spensieri on 11/25/13.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKNavigationViewController.h"
#import "SHKUtility.h"
#import "SmoochHelpKit+Private.h"
#import "SHKTutorialView.h"
#import "SHKMessagesButtonView.h"
#import "SHKArticleViewController.h"
#import "SHKPulsingCircleContainerView.h"
#import "SHKRecommendationsViewController.h"
#import "SHKHomeViewController.h"
#import "SHKOffsetManager.h"
#import "SHKTransition.h"
#import "SHKSearchBarView.h"
#import "SHKRecommendations.h"
#import "SHKAppColorExtractor.h"
#import "SHKStateMachine.h"

// Static
static const int kFinalNavBarYCoordinateActive = 20;
static const int kNavBarYCoordinateInactive = -84;

@interface SHKNavigationViewController ()

@property SHKTutorialView* tutorialView;
@property SHKPulsingCircleContainerView* circle;
@property BOOL gestureHintSkipped;
@property BOOL firstLaunch;
@property(weak) SHKStateMachine* stateMachine;

@end

@implementation SHKNavigationViewController

-(id)initWithRootViewController:(UIViewController *)rootViewController
{
    return [self initWithRootViewController:rootViewController andStateMachine:[SHKStateMachine sharedInstance]];
}

-(id)initWithRootViewController:(UIViewController *)rootViewController andStateMachine:(SHKStateMachine*)stateMachine
{
    self = [super initWithRootViewController:rootViewController];
    if(self){
        self.stateMachine = stateMachine;
        self.firstLaunch = YES;
        self.delegate = self;
        
        self.navigationBar.translucent = YES;
        [self.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
        self.navigationBar.shadowImage = [UIImage new];
        
        [self updateTintColor];
    }
    return self;
}

-(void)updateTintColor
{
    if ([[SHKAppColorExtractor sharedInstance] hasAppColors]) {
        self.navigationBar.tintColor = [SHKAppColorExtractor sharedInstance].darkenedPrimaryColor;
    }
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    [self removePulsingDot];
}

-(void)onOffsetChanged:(NSNotification*)notification
{
    SHKOffsetManager* offsetManager = notification.object;
    
    [self placeNavBar:offsetManager.offsetPercentage];
    [self.messagesButton reframeAnimated:NO];
    [self updateStatusBar];
    [self setTutorialViewAlpha:offsetManager.offsetPercentage];
}

-(void)placeNavBar:(CGFloat)percentage
{
    percentage = MIN(1, percentage);
    
    CGFloat yCoordinateOnScreen = [[UIApplication sharedApplication] isStatusBarHidden] ? 0 : kFinalNavBarYCoordinateActive;
    
    CGFloat slope = yCoordinateOnScreen - kNavBarYCoordinateInactive;
    CGFloat yIntercept = kNavBarYCoordinateInactive;
    
    CGFloat currentYCoordinate = (slope * percentage) + yIntercept;
    
    [self.navigationBar setFrame:CGRectMake(self.navigationBar.frame.origin.x,
                                            currentYCoordinate,
                                            self.navigationBar.frame.size.width,
                                            self.navigationBar.frame.size.height)];
}

-(void)setTutorialViewAlpha:(CGFloat)percentage
{
    if(self.tutorialView.hidden){
        return;
    }
    
    if(percentage > SHKOffsetManagerSemiActivePercentage){
        [self.tutorialView cancelAnimation];
    }
    
    // 100% alpha at SHKOffsetManagerSemiActivePercentage, 0% alpha at SHKOffsetManagerActivePercentage
    CGFloat slope = -1.0 / (SHKOffsetManagerActivePercentage - SHKOffsetManagerSemiActivePercentage);
    CGFloat yIntercept = -slope;
    
    CGFloat alpha = MIN(1, slope * percentage + yIntercept);
    
    self.tutorialView.alpha = alpha;
    [SmoochHelpKit darkenUnderlayWithAlpha:alpha];
}

-(void)smoochDidBecomeActive
{
    if([self conversationOnly]){
        [self presentViewController:[Smooch newConversationViewController] animated:YES completion:nil];
    }
    
    self.tutorialView.hidden = YES;
    [SmoochHelpKit lightenUnderlay];
    [UIView animateWithDuration:0.2
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         self.visibleViewController.view.alpha = 1;
                     } completion:nil];
}

-(void)smoochDidBeginTransition:(NSNotification*)notification
{
    SHKTransition* transition = notification.object;
    [self handleTransition:transition visibleViewController:self.visibleViewController];
}

-(void)handleTransition:(SHKTransition*)transition visibleViewController:(UIViewController*)visibleViewController
{
    if(transition.sourceState == SmoochStateActive){
        [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{
            visibleViewController.view.alpha = 0;
        } completion:nil];
        [self removePulsingDot];
    }
}

- (void)skipGestureHint
{
    self.gestureHintSkipped = YES;
    [self.stateMachine transitionToState:SmoochStateActive];
}

-(void)cancelGestureHint
{
    self.tutorialView.hidden = YES;
    [SmoochHelpKit lightenUnderlay];
}

- (void)showGestureHint
{
    self.gestureHintSkipped = NO;
    self.tutorialView.hidden = NO;
    [self.tutorialView startAnimation];
    
    self.stateMachine.currentState = SmoochStateSemiActive;
    [self.stateMachine.offsetManager animateToPercentage:SHKOffsetManagerSemiActivePercentage isDragging:NO withCompletion:nil];
}

-(BOOL)appWideGestureHandlerShouldBeginGesture:(SHKAppWideGestureHandler *)gestureHandler
{
    return !self.presentedViewController;
}

-(BOOL)stateMachine:(SHKStateMachine*)stateMachine shouldChangeToState:(SmoochState)state
{
    if(state == SmoochStateInactive && !self.tutorialView.hidden){
        [stateMachine.offsetManager animateToPercentage:SHKOffsetManagerSemiActivePercentage isDragging:NO withCompletion:nil];
        [self.tutorialView startAnimation];
        return NO;
    }
    return YES;
}

-(void)showArticle:(NSString*)url
{
    SHKArticleViewController* vc = [[SHKArticleViewController alloc] initWithUrlString:url];
    
    if([self.visibleViewController isKindOfClass:[SHKHomeViewController class]]){
        SHKHomeViewController* homeVC = (SHKHomeViewController*)self.visibleViewController;
        [vc setSearchText:homeVC.searchBar.text];
        vc.showsSearchBar = YES;
    }
    
    [self pushViewController:vc animated:YES];
}

- (BOOL)hasSearch
{
    return ( (self.viewControllers.count > 0) && [self.viewControllers[0] isKindOfClass:[SHKHomeViewController class]] );
}

-(BOOL)conversationOnly
{
    BOOL hasRecommendations = [SmoochHelpKit getRecommendations].recommendationsList.count > 0;
    
    return ![self hasSearch] && !hasRecommendations;
}

-(void) showConversation
{
    [Smooch showConversationFromViewController:self];
}

-(void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion
{
    [super dismissViewControllerAnimated:flag completion:^{
        if([self conversationOnly]){
            [[SHKStateMachine sharedInstance] transitionToState:SmoochStateInactive];
        }
        
        if(completion){
            completion();
        }
    }];
}

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.navigationBar setBarTintColor:nil];
    [self.navigationBar setTranslucent:NO];
    [self.navigationBar setTintColor:[UIColor blackColor]];
    
    self.messagesButton = [[SHKMessagesButtonView alloc] initWithTarget:self action:@selector(showConversation)];
    [self.view addSubview:self.messagesButton];
    
    self.tutorialView = [[SHKTutorialView alloc] initWithFrame:self.view.bounds];
    [self.tutorialView.skipButton addTarget:self action:@selector(skipGestureHint) forControlEvents:UIControlEventTouchUpInside];
    self.tutorialView.hidden = YES;
    [self.view addSubview:self.tutorialView];
}

-(void) showPulsingDot
{
    if (![self hasSearch]) {
        // Don't show pulsing dot
        // if there is no search bar.
        return;
    }
    
    [self removePulsingDot];
    
    CGRect dotFrame = CGRectMake(0, 50, 100, 100);
    // center on the navbar + 100 offset
    dotFrame.origin.x = CGRectGetMidX(self.navigationBar.frame) - dotFrame.size.width/2 + 100;
    self.circle = [[SHKPulsingCircleContainerView alloc] initWithFrame:dotFrame];
    self.circle.alpha = 0;
    [self.view addSubview:self.circle];
    [self.view bringSubviewToFront:self.circle];
    
    [UIView animateWithDuration:1.0f
                          delay:0.2f
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         self.circle.alpha = 1;
                         
                         // center the dot in the middle of the nav bar
                         CGRect navFrame = self.navigationBar.frame;
                         CGRect frame = self.circle.frame;
                         frame.origin.y = CGRectGetMidY(navFrame) - frame.size.height/2 + 7;
                         frame.origin.x = CGRectGetMidX(self.navigationBar.frame) - dotFrame.size.width/2 + 20;
                         self.circle.frame = frame;
                     }
                     completion:^(BOOL finished){
                         if(finished){
                             [self.circle pulseXTimes:3];
                             [UIView animateWithDuration:0.5f
                                                   delay:2.0f
                                                 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseOut
                                              animations:^{
                                                  self.circle.alpha = 0;
                                              }
                                              completion:nil];
                         }
                     }];
}

- (void) removePulsingDot
{
    if ([self hasSearch] && self.circle) {
        [self.circle.layer removeAllAnimations];
        [self.circle removeFromSuperview];
        self.circle = nil;
    }
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if(self.firstLaunch){
        self.visibleViewController.view.alpha = 0.0;
        self.firstLaunch = NO;
    }
    
    [self placeNavBar:[SHKStateMachine currentPercentage]];
    [self.messagesButton reframeAnimated:NO];
    
    [self registerForNotifications];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    
    if([self isNavigationBarHidden]){
        [self setNavigationBarHidden:NO animated:NO];
    }
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    //More fighting with UINavigationController to hide the nav bar when rotating 180 degrees fron landscape.
    if(!self.tutorialView.hidden){
        if(UIInterfaceOrientationIsLandscape(self.interfaceOrientation) && UIInterfaceOrientationIsLandscape(toInterfaceOrientation)){
            [self setNavigationBarHidden:YES animated:NO];
        }
    }
    
    [self.messagesButton reframeAnimated:YES withOrientation:toInterfaceOrientation];
}

-(void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    // UINavigationController fights to keep the nav bar in one place. We need to fight back.
    [self placeNavBar:[SHKStateMachine currentPercentage]];
    [self.messagesButton reframeAnimated:NO];
}

-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    self.tutorialView.frame = self.view.bounds;
    
    if(self.circle.layer.animationKeys){
        [self removePulsingDot];
        [self showPulsingDot];
    }
}

-(void)applicationDidBecomeActive
{
    // Still fighting. Keeps nav bar in place when app returns from background
    dispatch_async(dispatch_get_main_queue(), ^{
        [self placeNavBar:[SHKStateMachine currentPercentage]];
        [self.messagesButton reframeAnimated:NO];
    });
}

-(void)updateStatusBar
{
    if(self.preferredStatusBarStyle != [UIApplication sharedApplication].statusBarStyle){
        [self setNeedsStatusBarAppearanceUpdate];
        [[UIApplication sharedApplication] setStatusBarStyle:self.preferredStatusBarStyle animated:YES];
    }
}

-(void)endEditing
{
    if([self.visibleViewController respondsToSelector:@selector(endEditing)]){
        [self.visibleViewController performSelector:@selector(endEditing) withObject:nil];
    }
}

-(UIStatusBarStyle)preferredStatusBarStyle
{
    if([SHKStateMachine currentPercentage] > SHKOffsetManagerInactivePercentage){
        return UIStatusBarStyleDefault;
    }else{
        return [SmoochHelpKit getAppStatusBarStyle];
    }
}

-(BOOL)shouldAutorotate
{
    return [SHKGetTopMostViewControllerOfRootWindow() shouldAutorotate];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return [SHKGetTopMostViewControllerOfRootWindow() supportedInterfaceOrientations];
}

-(void)registerForNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    if ([self hasSearch]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showPulsingDot) name:SHKRecommendationsViewControllerReachedEndOfRecommandation object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removePulsingDot) name:SHKSearchBarTextDidBeginEditing object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removePulsingDot) name:SHKRecommendationsViewControllerReachedSecondToLastRecommendation object:nil];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(smoochDidBeginTransition:) name:SHKStateMachineDidEnterTransitioningStateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(smoochDidBecomeActive) name:SHKStateMachineDidEnterActiveStateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onOffsetChanged:) name:SHKOffsetManagerDidChangePercentageNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTintColor) name:SHKAppColorUpdatedNotification object:nil];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
