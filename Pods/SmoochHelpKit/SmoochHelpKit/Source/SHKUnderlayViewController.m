//
//  SHKUnderlayViewController.m
//  Smooch
//
//  Created by Michael Spensieri on 2/11/14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKUnderlayViewController.h"
#import "SHKUtility.h"
#import "SHKWindow.h"
#import "SHKAppColorExtractor.h"
#import "SHKStateMachine.h"
#import "SHKTransition.h"
#import "SHKAlphaGradientLayer.h"
#import "SHKRecommendations.h"
#import "SmoochHelpKit+Private.h"

@interface SHKUnderlayViewController ()

@property UIView* blackView;
@property SHKAlphaGradientLayer *ghostLayer;

@end

@implementation SHKUnderlayViewController

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    self.gradientView = [[SHKGradientView alloc] initWithFrame:self.view.bounds];
    self.dropShadowViewForWindow = [[SHKDropShadowView alloc] initWithFrame:self.view.bounds];
    
    [self.view addSubview:self.gradientView];
    [self.view addSubview:self.dropShadowViewForWindow];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBeginTransition:) name:SHKStateMachineDidEnterTransitioningStateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeSemiActive) name:SHKStateMachineDidEnterSemiActiveStateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resizingNotif:) name:SmoochWindowResizingNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardShown) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardHidden) name:UIKeyboardWillHideNotification object:nil];
}

-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    self.gradientView.frame = self.view.bounds;
    self.blackView.transform = CGAffineTransformIdentity;;
    self.blackView.frame = self.view.bounds;
    [self resizeDropShadowAnimated:NO];
    [self reframeGhostLayer];
}

-(void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    self.dropShadowViewForWindow.hidden = YES;
    
    if(!self.view.window.hidden){
        [UIApplication sharedApplication].delegate.window.hidden = YES;
    }
}

-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    
    [UIView animateWithDuration:0.1 animations:^{
        [UIApplication sharedApplication].delegate.window.hidden = NO;
        self.dropShadowViewForWindow.hidden = NO;
    }];
}

-(void)didBeginTransition:(NSNotification*)notification
{
    SHKTransition* transition = notification.object;
    if(transition.sourceState == SmoochStateInactive){
        [[SHKAppColorExtractor sharedInstance] extractAppColors];
    }
}

-(void)didBecomeSemiActive
{
    [[SHKAppColorExtractor sharedInstance] extractAppColors];
}

-(void)resizingNotif:(NSNotification*)notification
{
    BOOL isDragging = [notification.userInfo[@"dragging"] boolValue];
    [self resizeDropShadowAnimated:!isDragging];
}

-(void)resizeDropShadowAnimated:(BOOL)animated
{
    [self.dropShadowViewForWindow reframe:self.view.bounds];
    [self.dropShadowViewForWindow resizeAnimated:animated];
    
    self.dropShadowViewForWindow.alpha = [UIApplication sharedApplication].delegate.window.alpha;
}

-(void)lighten
{
    self.blackView.hidden = YES;
}

-(void)darkenWithAlpha:(CGFloat)alpha
{
    if (nil == self.blackView) {
        self.blackView = [[UIView alloc] initWithFrame:self.view.bounds];
        self.blackView.backgroundColor = [UIColor blackColor];
        [self.view addSubview:self.blackView];
    }
    
    self.blackView.hidden = NO;
    self.blackView.alpha = alpha;
}

-(void)reframeGhostLayer
{
    self.ghostLayer.transform = CATransform3DIdentity;
    CGRect frame = CGRectZero;
    frame.size = SHKOrientedScreenSize();
    self.ghostLayer.frame = frame;
}

- (void)initGhostLayer
{
    self.ghostLayer = [[SHKAlphaGradientLayer alloc] init];
    [self.ghostLayer setGradientPointsForOrientation:UIInterfaceOrientationPortrait];
    [self reframeGhostLayer];
    self.ghostLayer.masksToBounds = NO;
    [self.dropShadowViewForWindow.layer setMask:self.ghostLayer];
}

- (void)removeGhostLayer
{
    [self.dropShadowViewForWindow.layer setMask:nil];
    self.ghostLayer = nil;
}

-(void)keyboardShown
{
    if([SHKStateMachine currentState] == SmoochStateActive && [SmoochHelpKit getRecommendations].recommendationsList.count == 0){
        [self initGhostLayer];
    }
}

-(void)keyboardHidden
{
    [self removeGhostLayer];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(BOOL)shouldAutorotate
{
    return [SHKGetTopMostViewControllerOfRootWindow() shouldAutorotate];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return [SHKGetTopMostViewControllerOfRootWindow() supportedInterfaceOrientations];
}

@end
