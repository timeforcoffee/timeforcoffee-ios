//
//  SmoochHelpKit.h
//  Smooch
//
//  Created by Mike Spensieri on 2015-10-11.
//  Copyright © 2015 Smooch Technologies. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SHKSettings.h"

@interface SmoochHelpKit : NSObject

/**
 *  @abstract Initialize the Smooch Help Center with the provided settings.
 *
 *  @discussion This may only be called once (preferably, in application:didFinishLaunchingWithOptions:).
 *
 *  Use +settings to retrieve and modify the given settings object.
 *
 *  @see SHKSettings
 *
 *  @param settings The settings to use.
 */
+(void)initWithSettings:(SHKSettings*)settings;

/**
 *  @abstract Deinitialize the Smooch Help Center.
 *
 *  @discussion Removes and deallocates all UI elements and settings objects.
 */
+(void)destroy;

/**
 *  @abstract Accessor method for the help center settings.
 *
 *  @discussion Use this object to update settings at run time.
 *
 *  Note: Some settings may only be configured at init time. See the SHKSettings class reference for more information.
 *
 *  @see SHKSettings
 *
 *  @return Settings object passed in +initWithSettings:, or nil if +initWithSettings: hasn't been called yet.
 */
+(SHKSettings*)settings;

/**
 *  @abstract Presents the Smooch Home screen.
 *
 *  @discussion Calling this method with search disabled and no recommendations configured is equivalent to calling +showConversation.
 *
 *  +initWithSettings: must have been called prior to calling this method.
 */
+(void)show;

/**
 *  @abstract Displays the Smooch gesture hint.
 *
 *  @discussion Upon completing (or skipping) the hint, the user will land on the Smooch Home screen (equivalent to calling +show)
 *
 *  +initWithSettings: must have been called prior to calling this method.
 */
+(void)showWithGestureHint;

/**
 *  @abstract Dismisses Smooch Help Center if shown.
 *
 *  @discussion +initWithSettings: must have been called prior to calling this method.
 */
+(void)close;

/**
 *  @abstract Set a list of recommendations that the user will see upon launching Smooch.
 *
 *  @discussion Recommendations are web resources that communicate important information to your users. For example: knowledge base articles, frequently asked questions, new feature announcements, etc... Recommendations are displayed when the +show API is called, or when Smooch is launched using the app-wide gesture.
 *
 *  Array items must be of type NSString, and should represent the URLs of the recommendations.
 *
 *  Passing nil will remove any existing default recommendations.
 *
 *  @param urlStrings The array of url strings.
 */
+(void)setDefaultRecommendations:(NSArray*)urlStrings;

/**
 *  @abstract Sets the top recommendation, to be displayed when the Smooch UI is shown.
 *
 *  @discussion The top recommendation is displayed at the beginning of the recommendations list and takes precedence over default recommendations.
 *
 *  This should be used when there is a one-to-one mapping between an event (or error) that occurred in the app, and a corresponding article explaining or elaborating on that event.
 *
 *  Calling this method more than once will replace the previous top recommendation.
 *  Passing nil will remove the current top recommendation.
 *
 *  @param urlString The url of the article to be displayed.
 */
+(void)setTopRecommendation:(NSString*)urlString;

@end
