//
//  SmoochHelpKit.m
//  Smooch
//
//  Created by Mike Spensieri on 2015-10-11.
//  Copyright © 2015 Smooch Technologies. All rights reserved.
//

#import "SmoochHelpKit.h"
#import "SHKHomeViewController.h"
#import "SHKNavigationViewController.h"
#import "SHKOverlayWindow.h"
#import "SHKUnderlayViewController.h"
#import "SHKRecommendations.h"
#import "SHKRecommendationsViewController.h"
#import "SHKSearchController.h"
#import "SHKUtility.h"
#import <CoreText/CoreText.h>

static SHKNavigationViewController* navigationController;
static UIStatusBarStyle appStatusBarStyle;
static SHKOverlayWindow* overlayWindow;
static SHKWindow* backgroundWindow;
static SHKRecommendations* recommendations;
static BOOL delaySmoochInit = NO;
static BOOL appDidFinishLaunching = NO;
static SHKSettings* settings;

const int SHKBadKnowledgeBaseUrlErrorCode = 100;
NSString* const SHKBadKnowledgeBaseUrlErrorText = @"<Smooch: ERROR> Provided Knowledge Base URL must contain http:// or https:// and be valid as per NSURL";

// Must remain as SKT for backwards compatibility
static NSString* const kSmoochWasLaunched = @"SKTSupportKitWasLaunched";

@implementation SmoochHelpKit

+(SHKSettings*)settings
{
    return settings;
}

+(void)initWithSettings:(SHKSettings*)newSettings
{
    if(newSettings == nil){
        NSLog(@"<Smooch: ERROR> Init called with nil settings, aborting init sequence!");
    }else if(settings){
        NSLog(@"<Smooch: ERROR> Init called more than once, aborting init sequence!");
    }else{
        settings = newSettings;
        
        [Smooch initWithSettings:settings];
        
        if (appDidFinishLaunching) {
            [self completeInit];
        }else{
            delaySmoochInit = YES;
        }
    }
}

+(void)completeInit
{
    [self loadSymbolFont];
    
    if ([UIApplication sharedApplication] && ([[[UIApplication sharedApplication] windows] count] > 0)) {
        [self ensureWindowsExist];
        [self loadViewControllers];
        
        if(settings.enableAppWideGesture){
            [overlayWindow attachGestureRecognizers];
        }
    } else {
        NSLog(@"<Smooch: ERROR> No UIWindow found. Ensure you call initWithSettings: after a UIWindow is allocated.");
    }
}

+(void)destroy
{
    settings = nil;
    
    SHKEnsureMainThread(^{
        if([SHKStateMachine sharedInstance].currentState != SmoochStateInactive){
            [[SHKStateMachine sharedInstance] transitionToState:SmoochStateInactive withCompletion:^{
                [self deinitUI];
            }];
        }else{
            [self deinitUI];
        }
    });
}

+(void)deinitUI
{
    SHKEnsureMainThread(^{
        overlayWindow = nil;
        backgroundWindow = nil;
        navigationController = nil;
    });
}

+(void)ensureWindowsExist
{
    if(!backgroundWindow){
        backgroundWindow = [[SHKWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        
        backgroundWindow.windowLevel = -1;
    }
    
    if(!overlayWindow){
        appStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;
        
        overlayWindow = [[SHKOverlayWindow alloc] initWithFrame:[UIScreen mainScreen].bounds settings:settings];
        
        // we put ourself above normal but below keyboard
        overlayWindow.windowLevel = UIWindowLevelNormal + 5;
    }
}

+(void)loadViewControllers
{
    if(overlayWindow.rootViewController){
        return;
    }
    
    if(settings.knowledgeBaseURL){
        SHKSearchController* searchController = [SHKSearchController searchControllerWithSettings:settings];
        
        SHKHomeViewController* vc = [[SHKHomeViewController alloc] initWithSearchController:searchController];
        
        if (!SHKIsValidZendeskUrl(settings.knowledgeBaseURL)) {
            [vc showBadUrlError];
        }
        
        navigationController = [[SHKNavigationViewController alloc] initWithRootViewController:vc];
    }else{
        navigationController = [[SHKNavigationViewController alloc] initWithRootViewController:[[SHKRecommendationsViewController alloc] init]];
    }
    
    backgroundWindow.rootViewController = [[SHKUnderlayViewController alloc] init];
    
    // Hidden = NO to load the view controllers, then hide back the window
    backgroundWindow.hidden = NO;
    backgroundWindow.hidden = YES;
    
    overlayWindow.rootViewController = navigationController;
    
    // Hidden = NO to load the view controllers, then hide back the window
    overlayWindow.hidden = NO;
    overlayWindow.hidden = YES;
}

+(BOOL)isPreparedToShow
{
    if(!settings){
        NSLog(@"<Smooch: ERROR> Show called before settings have been initialized!");
        return NO;
    }
    
    [self ensureWindowsExist];
    
    if (!SHKIsValidZendeskUrl(settings.knowledgeBaseURL)) {
        if([navigationController.visibleViewController isKindOfClass:[SHKHomeViewController class]]){
            SHKHomeViewController* searchVC = (SHKHomeViewController*)navigationController.visibleViewController;
            [searchVC showBadUrlError];
        }
    }
    
    return YES;
}

+(void)show
{
    if ([self isPreparedToShow]) {
        if ([self shouldShowHint]) {
            [navigationController showGestureHint];
        }else{
            [[SHKStateMachine sharedInstance] transitionToState:SmoochStateActive];
        }
    }
}

+(void)showWithGestureHint
{
    if(settings.enableAppWideGesture){
        if ([self isPreparedToShow]){
            [navigationController showGestureHint];
        }
    }else{
        NSLog(@"<Smooch: ERROR> Failed to show gesture hint because the gesture is not enabled.  Enable it in your SHKSettings to display it.");
    }
}

+(void)close
{
    if(!settings){
        NSLog(@"<Smooch: ERROR> Close called before settings have been initialized!");
        return;
    }
    
    if([SHKStateMachine currentState] == SmoochStateActive){
        if(navigationController.presentedViewController){
            [navigationController.presentedViewController dismissViewControllerAnimated:YES completion:^{
                [[SHKStateMachine sharedInstance] transitionToState:SmoochStateInactive];
            }];
        }else{
            [[SHKStateMachine sharedInstance] transitionToState:SmoochStateInactive];
        }
    }else if([SHKStateMachine currentState] == SmoochStateSemiActive || [SHKStateMachine currentState] == SmoochStateTransitioning){
        [navigationController cancelGestureHint];
        [[SHKStateMachine sharedInstance] transitionToState:SmoochStateInactive];
    }
}

+(SHKOverlayWindow*)overlayWindow
{
    return overlayWindow;
}

// Dynamically load the font instead of declaring it in app's info.plist
// http://www.marco.org/2012/12/21/ios-dynamic-font-loading
+ (void)loadSymbolFont
{
    NSString *fontPath = [[self getResourceBundle] pathForResource:@"ios7-icon" ofType:@"ttf"];
    
    if(fontPath == nil){
        NSLog(@"<Smooch: ERROR> Could not find ios7-icon.ttf resource. Please include it in your project's \"Copy Bundle Resources\" build phase");
        return;
    }
    
    // Fix deadlock. See http://lists.apple.com/archives/cocoa-dev/2010/Sep/msg00451.html and http://stackoverflow.com/questions/24900979/cgfontcreatewithdataprovider-hangs-in-airplane-mode
    [UIFont familyNames];
    
    NSData *inData = [NSData dataWithContentsOfFile:fontPath];
    CFErrorRef error;
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)inData);
    CGFontRef font = CGFontCreateWithDataProvider(provider);
    
    CTFontManagerRegisterGraphicsFont(font, &error);
    
    CFRelease(font);
    CFRelease(provider);
}

+(UIImage*)getImageFromResourceBundle:(NSString*)imageName
{
    UIImage* image = [UIImage imageNamed:imageName];
    
    if(!image){
        image = [UIImage imageWithContentsOfFile:[[self getResourceBundle] pathForResource:imageName ofType:@"png"]];
    }
    
    return image;
}

+ (NSBundle *)getResourceBundle
{
    static NSBundle* frameworkBundle = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        NSString* mainBundlePath = [[NSBundle mainBundle] resourcePath];
        NSString* frameworkBundlePath = [mainBundlePath stringByAppendingPathComponent:@"SHKResources.bundle"];
        frameworkBundle = [NSBundle bundleWithPath:frameworkBundlePath];
    });
    return frameworkBundle;
}

+(void)load
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidFinishLaunching:)
                                                 name:UIApplicationDidFinishLaunchingNotification
                                               object:nil];
}

+(void)applicationDidFinishLaunching:(NSNotification*)notification
{
    appDidFinishLaunching = YES;
    if (delaySmoochInit) {
        delaySmoochInit = NO;
        [self completeInit];
    }
}

+(UIStatusBarStyle)getAppStatusBarStyle
{
    return appStatusBarStyle;
}

+(void)setAppStatusBarStyle:(UIStatusBarStyle)style
{
    appStatusBarStyle = style;
}

+(BOOL)shouldShowHint
{
    BOOL isFirstLaunch;
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:kSmoochWasLaunched]) {
        isFirstLaunch = NO;
    } else {
        isFirstLaunch = YES;
        [defaults setBool:YES forKey:kSmoochWasLaunched];
        [defaults synchronize];
    }
    return isFirstLaunch && settings.enableGestureHintOnFirstLaunch && settings.enableAppWideGesture;
}

+(void)lightenUnderlay
{
    SHKUnderlayViewController* vc = (SHKUnderlayViewController*)backgroundWindow.rootViewController;
    [vc lighten];
}

+(void)darkenUnderlayWithAlpha:(CGFloat)alpha
{
    SHKUnderlayViewController* vc = (SHKUnderlayViewController*)backgroundWindow.rootViewController;
    [vc darkenWithAlpha:alpha];
}

+(void)setDefaultRecommendations:(NSArray *)urlStrings
{
    [[self getRecommendations] setDefaultRecommendations:urlStrings];
}

+(void)setTopRecommendation:(NSString *)urlString
{
    [[self getRecommendations] setTopRecommendation:urlString];
}

+(SHKRecommendations*)getRecommendations
{
    if(recommendations == nil){
        recommendations = [SHKRecommendations new];
    }
    return recommendations;
}

@end
