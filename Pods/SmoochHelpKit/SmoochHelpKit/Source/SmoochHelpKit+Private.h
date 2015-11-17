//
//  SmoochHelpKit+Private.h
//  Smooch
//
//  Created by Mike Spensieri on 2015-10-11.
//  Copyright © 2015 Smooch Technologies. All rights reserved.
//

#import "SmoochHelpKit.h"
#import <UIKit/UIKit.h>
@class SHKRecommendations;
@class SHKOverlayWindow;

extern const int SHKBadKnowledgeBaseUrlErrorCode;
extern NSString* const SHKBadKnowledgeBaseUrlErrorText;

@interface SmoochHelpKit(Private)

+(void)setAppStatusBarStyle:(UIStatusBarStyle)style;
+(void)lightenUnderlay;
+(void)darkenUnderlayWithAlpha:(CGFloat)alpha;

+(SHKRecommendations*)getRecommendations;
+(UIStatusBarStyle)getAppStatusBarStyle;
+(SHKOverlayWindow*)overlayWindow;
+(NSBundle *)getResourceBundle;
+(UIImage*)getImageFromResourceBundle:(NSString*)imageName;

@end
