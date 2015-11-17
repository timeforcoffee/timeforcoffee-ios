//
//  SHKOverlayWindow.m
//  Smooch
//
//  Created by Michael Spensieri on 1/27/14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKOverlayWindow.h"
#import "SHKNavigationViewController.h"
#import "SmoochHelpKit+Private.h"
#import "SHKAppWideGestureHandler.h"
#import "SHKTransition.h"
#import "SHKUtility.h"
#import "SHKOffsetManager.h"
#import "SHKSettings.h"

static const CGFloat kMaxScaleDownFactor = 0.66;
static const CGFloat kAdditionalLandscapeScaleDownFactor = 0.15;

@interface SHKOverlayWindow()

@property UIWindow* mainWindow;
@property SHKAppWideGestureHandler* gestureHandler;

// Used to temporarily store the main window's transform during status bar height change
@property CGAffineTransform windowTransform;

@property BOOL observerRegistered;

@property SHKSettings* sdkSettings;

@end

@implementation SHKOverlayWindow

+(CGFloat)getMaxScaleDownFactor
{
    return SHKIsLayoutPhoneInLandscape() ? kMaxScaleDownFactor - kAdditionalLandscapeScaleDownFactor : kMaxScaleDownFactor;
}

-(instancetype)initWithFrame:(CGRect)frame
{
    return [self initWithFrame:frame settings:nil];
}

-(instancetype)initWithFrame:(CGRect)frame settings:(SHKSettings *)settings
{
    self = [super initWithFrame:frame];
    if (self) {
        _sdkSettings = settings;
        [_sdkSettings addObserver:self forKeyPath:@"enableAppWideGesture" options:0 context:nil];
        
        _observerRegistered = NO;
        
        _mainWindow = [UIApplication sharedApplication].delegate.window;
        _mainWindow.clipsToBounds = YES;
        
        _gestureHandler = [[SHKAppWideGestureHandler alloc] initWithStateMachine:[SHKStateMachine sharedInstance]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resizeWindow:) name:SHKOffsetManagerDidChangePercentageNotification object:nil];
    }
    return self;
}

-(void)dealloc
{
    [self.sdkSettings removeObserver:self forKeyPath:@"enableAppWideGesture"];
}

-(void)startWatchingForFrameChangesOnMainWindow
{
    if(!self.observerRegistered){
        [self.mainWindow addObserver:self forKeyPath:@"frame" options:NSKeyValueObservingOptionNew context:nil];
        self.observerRegistered = YES;
    }
}

-(void)stopWatchingForFrameChangesOnMainWindow
{
    if(self.observerRegistered){
        [self.mainWindow removeObserver:self forKeyPath:@"frame"];
        self.observerRegistered = NO;
    }
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if(object == self.sdkSettings){
        [self attachGestureRecognizers];
        return;
    }
    
    // If the main window changes frame to something other than the screen size, force it back.
    // Fixes an issue where presenting a fullscreen video while smooch is active caused the main window to be horribly mis-sized
    if(!CGRectEqualToRect([change[NSKeyValueChangeNewKey] CGRectValue], [UIScreen mainScreen].bounds)){
        dispatch_async(dispatch_get_main_queue(), ^{
            self.windowTransform = self.mainWindow.transform;
            self.mainWindow.transform = CGAffineTransformIdentity;
            self.mainWindow.frame = [UIScreen mainScreen].bounds;
            self.mainWindow.transform = self.windowTransform;
        });
    }
}

-(void)setRootViewController:(SHKNavigationViewController *)rootViewController
{
    self.gestureHandler.delegate = rootViewController;
    [SHKStateMachine sharedInstance].delegate = rootViewController;
    [super setRootViewController:rootViewController];
}

-(void)attachGestureRecognizers
{
    if(self.sdkSettings.enableAppWideGesture){
        if(self.isKeyWindow){
            [self.gestureHandler addAppWideGestureTo:self];
        }else{
            [self.gestureHandler addAppWideGestureTo:self.mainWindow];
        }
    }else{
        [self.gestureHandler removeAppWideGesture];
    }
}

-(void)appWillChangeStatusBarHeight
{
    self.windowTransform = self.mainWindow.transform;
    self.mainWindow.transform = CGAffineTransformIdentity;
}

-(void)appDidChangeStatusBarHeight
{
    self.mainWindow.transform = self.windowTransform;
}

-(void)smoochDidBecomeSemiActive
{
    [self endEditing];
    [self cacheStatusBarColor];
    [self startReceivingTouches];
}

-(void)startReceivingTouches
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self makeKeyWindow];
        [self attachGestureRecognizers];
    });
}

-(void)smoochDidBecomeInactive
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.mainWindow makeKeyWindow];
        [self attachGestureRecognizers];
    });
}

-(void)smoochDidBeginTransition:(SHKTransition *)transition
{
    if (transition.sourceState == SmoochStateInactive) {
        [self cacheStatusBarColor];
        
        [self startReceivingTouches];
    }
    
    [self endEditing];
}

-(void)cacheStatusBarColor
{
    [SmoochHelpKit setAppStatusBarStyle:[UIApplication sharedApplication].statusBarStyle];
}

-(void)resizeWindow:(NSNotification*)notification
{
    SHKOffsetManager* offsetManager = notification.object;
    CGFloat percentage = offsetManager.offsetPercentage;
    
    // Don't ask about the magic numbers....
    
    CGFloat windowScale = 1.0;
    if(percentage <= 1){
        windowScale = 1 - (percentage * (1 - [self.class getMaxScaleDownFactor]));
    }else{
        windowScale = 0.1 / (percentage - 0.55) + [self.class getMaxScaleDownFactor] - 0.22;
    }
    
    CGFloat windowAlpha = 9.1 * windowScale - 3.9;
    if(SHKIsLayoutPhoneInLandscape()){
        windowAlpha = 8.3 * windowScale - 2.25;
    }
    windowAlpha = MIN(1, MAX(0.5, windowAlpha));
    
    self.mainWindow.transform = CGAffineTransformScale(CGAffineTransformIdentity, windowScale, windowScale);
    self.mainWindow.alpha = windowAlpha;
    [[NSNotificationCenter defaultCenter] postNotificationName:SmoochWindowResizingNotification object:self userInfo:notification.userInfo];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if(self.isKeyWindow){
        return [super hitTest:point withEvent:event];
    }
    
    return [self.mainWindow hitTest:point withEvent:event];
}

- (BOOL)endEditing
{
    if(self.isKeyWindow){
        [(SHKNavigationViewController*)self.rootViewController endEditing];
        return YES;
    }
    
    UIViewController* topMostViewController = SHKGetTopMostViewControllerOfRootWindow();
    return [topMostViewController.view endEditing:YES];
}

@end
