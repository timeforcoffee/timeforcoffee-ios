//
//  SHKUtility.m
//  Smooch
//
//  Created by Michael Spensieri on 12/4/13.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKUtility.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <arpa/inet.h>

static const int SMOOCH_STATUS_BAR_HEIGHT = 20;
static const int SMOOCH_NAV_BAR_HEIGHT = 44;
static const int SMOOCH_NAV_BAR_HEIGHT_LANDSCAPE_IPHONE = 32;
static SCNetworkConnectionFlags SMOOCH_CONNECTION_FLAGS;
static SCNetworkReachabilityRef SMOOCH_REACHABILITY;

BOOL SHKIsIOS8OrLater()
{
    return floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_7_1;
}

CGSize SHKAbsoluteScreenSize()
{
    CGSize size = [UIScreen mainScreen].bounds.size;
    if(SHKIsIOS8OrLater()){
        if(UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)){
            CGFloat t = size.width;
            size.width = size.height;
            size.height = t;
        }
    }
    return size;
}

CGSize SHKOrientedScreenSize()
{
    CGSize size = [UIScreen mainScreen].bounds.size;
    if(!SHKIsIOS8OrLater()){
        if(UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)){
            CGFloat t = size.width;
            size.width = size.height;
            size.height = t;
        }
    }
    return size;
}

void SHKEnsureMainThread(void (^block)(void))
{
    if([[NSThread currentThread] isMainThread]){
        block();
    }else{
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

BOOL SHKIsTallScreenDevice()
{
    return SHKAbsoluteScreenSize().height > 500;
}

BOOL SHKIsIpad()
{
   return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
}

BOOL SHKIsLayoutPhoneInLandscape()
{
    return UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation) && !SHKIsIpad();
}

BOOL SHKIsValidZendeskUrl(NSString* candidate)
{
    // ensure valid url as per NSURL
    if(![candidate isKindOfClass:[NSString class]] || [NSURL URLWithString:candidate] == nil){
        return NO;
    }
    
    // ensure http(s) is specified as each zendesk only supports one of the two
    NSString* url = [candidate lowercaseString];
    if ([url rangeOfString:@"https://"].location != NSNotFound || [url rangeOfString:@"http://"].location != NSNotFound) {
        return YES;
    }else{
        return NO;
    }
}

NSString* SHKAddIsMobileQueryParameter(NSString* string)
{
    NSURL* url = [[NSURL alloc] initWithString:string];
    
    NSString* leadingChar = url.query == nil ? @"?" : @"&";
    return [NSString stringWithFormat:@"%@%@%@", string, leadingChar, @"is_mobile=true"];
}

NSString* SHKGetAppDisplayName()
{
    NSString* appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?: [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    return appName ? appName : @"";
}

CGFloat SHKNavBarHeight()
{
    CGFloat height = SMOOCH_NAV_BAR_HEIGHT;
    
    if(SHKIsLayoutPhoneInLandscape()){
        height =  SMOOCH_NAV_BAR_HEIGHT_LANDSCAPE_IPHONE;
    }
    
    if(![[UIApplication sharedApplication] isStatusBarHidden]){
        height += SMOOCH_STATUS_BAR_HEIGHT;
    }
    
    return height;
}

BOOL SHKIsStatusBarTall()
{
    if([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortrait ||
       [UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortraitUpsideDown){
        return ([UIApplication sharedApplication].statusBarFrame.size.height > 20.0);
    }else{
        return ([UIApplication sharedApplication].statusBarFrame.size.width > 20.0);
    }
}

// Adapted from UIDevice-Reachability category
// https://github.com/erica/uidevice-extension/blob/master/UIDevice-Reachability.m
void SHKPingReachabilityInternal()
{
	if (!SMOOCH_REACHABILITY)
	{
		BOOL ignoresAdHocWiFi = NO;
		struct sockaddr_in ipAddress;
		bzero(&ipAddress, sizeof(ipAddress));
		ipAddress.sin_len = sizeof(ipAddress);
		ipAddress.sin_family = AF_INET;
		ipAddress.sin_addr.s_addr = htonl(ignoresAdHocWiFi ? INADDR_ANY : IN_LINKLOCALNETNUM);
		
		SMOOCH_REACHABILITY = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (struct sockaddr *)&ipAddress);
		CFRetain(SMOOCH_REACHABILITY);
	}
	
	// Recover reachability flags
    SCNetworkReachabilityGetFlags(SMOOCH_REACHABILITY, &SMOOCH_CONNECTION_FLAGS);
}

BOOL SHKIsNetworkAvailable()
{
	SHKPingReachabilityInternal();
	BOOL isReachable = ((SMOOCH_CONNECTION_FLAGS & kSCNetworkFlagsReachable) != 0);
    BOOL needsConnection = ((SMOOCH_CONNECTION_FLAGS & kSCNetworkFlagsConnectionRequired) != 0);
    return (isReachable && !needsConnection) ? YES : NO;
}

UIImage* SHKTakeScreenshotOfRootWindow()
{
    // Derived from https://developer.apple.com/library/ios/qa/qa1703/_index.html
    
    UIGraphicsBeginImageContextWithOptions([[UIScreen mainScreen] bounds].size, NO, 0);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    UIWindow* window = [UIApplication sharedApplication].delegate.window;
    if([window respondsToSelector:@selector(drawViewHierarchyInRect:afterScreenUpdates:)]){
        // See http://damir.me/ios7-blurring-techniques
        [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO];
    }else{
        [window.layer renderInContext:context];
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return image;
}

// Inspired from this StackOverflow answer: http://stackoverflow.com/a/17578272
UIViewController* SHKGetTopMostViewController(UIViewController* vc)
{
    if([vc isKindOfClass:[UINavigationController class]]){
        UINavigationController* navController = (UINavigationController*)vc;
        
        if(nil != navController.visibleViewController){
            return SHKGetTopMostViewController(navController.visibleViewController);
        }else{
            return navController;
        }
    }else if([vc isKindOfClass:[UITabBarController class]]){
        UITabBarController* tabController = (UITabBarController*)vc;
        
        if(nil != tabController.presentedViewController){
            return SHKGetTopMostViewController(tabController.presentedViewController);
        }else if(nil != tabController.selectedViewController){
            return SHKGetTopMostViewController(tabController.selectedViewController);
        }else{
            return tabController;
        }
    }else if(nil != vc.presentedViewController){
        return SHKGetTopMostViewController(vc.presentedViewController);
    }else{
        return vc;
    }
}

UIViewController* SHKGetTopMostViewControllerOfRootWindow()
{
    return SHKGetTopMostViewController([UIApplication sharedApplication].delegate.window.rootViewController);
}

CGFloat SHKGetSaturationOfColor(UIColor* color)
{
    CGFloat saturation;
    [color getHue:nil saturation:&saturation brightness:nil alpha:nil];
    return saturation;
}

UIImage* SHKFancyCharacterAsImageWithColor(NSString* character, CGFloat fontSize, UIColor* fontColor)
{
    UILabel* tempLabel = [[UILabel alloc] init];
    tempLabel.backgroundColor = [UIColor clearColor];
    tempLabel.textColor = fontColor;
    UIFont* iconFont = [UIFont fontWithName:@"ios7-icon" size:fontSize];
    
    // no icon if the font can't be loaded
    if(iconFont == nil){
        return nil;
    }
    
    tempLabel.font = iconFont;
    tempLabel.text = character;
    [tempLabel sizeToFit];
    
    UIGraphicsBeginImageContextWithOptions([tempLabel bounds].size, NO, 0);
    [[tempLabel layer] renderInContext: UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

UIImage* SHKFancyCharacterAsImage(NSString* character, CGFloat fontSize)
{
    return SHKFancyCharacterAsImageWithColor(character, fontSize, [UIColor whiteColor]);
}
