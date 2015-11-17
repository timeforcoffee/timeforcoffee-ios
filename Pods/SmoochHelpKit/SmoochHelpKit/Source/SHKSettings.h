//
//  SHKSettings.h
//  Smooch
//
//  Created by Mike Spensieri on 2015-10-11.
//  Copyright © 2015 Smooch Technologies. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Smooch/Smooch.h>

/**
 *  @discussion Filtering mode to use with the -excludeSearchResultsIf:categories:sections: API of SHKSettings.
 *
 *  @see SHKSettings
 */
typedef NS_ENUM(NSUInteger, SHKSearchResultsFilterMode) {
    /**
     *  Filter out search results if they belong to any of the passed section ids.
     */
    SHKSearchResultIsIn,
    /**
     *  Filter out search results if they do not belong to any of the passed section ids.
     */
    SHKSearchResultIsNotIn
};

@interface SHKSettings : SKTSettings

/**
 *  @abstract Initializes a settings object with the given app token.
 *
 *  @param appToken A valid app token retrieved from the Smooch web portal.
 */
+(instancetype)settingsWithAppToken:(NSString*)appToken;

/**
 *  @abstract Sets the filtering policy applied to user search results based on the given filter mode.
 *
 *  @discussion Filtering may only be configured once, and configuration must be done at init time or no filtering will be applied.
 *
 *  Filtering by category id is only possible for Zendesk instances that are using HelpKit.
 *
 *  @see SHKSearchResultsFilterMode
 *
 *  @param filterMode The filter mode to use.
 *  @param categories Array of category ids on which to filter search results. Can be objects of type NSString or NSNumber.
 *  @param sections Array of section ids on which to filter search results. Can be objects of type NSString or NSNumber.
 */
-(void)excludeSearchResultsIf:(SHKSearchResultsFilterMode)filterMode categories:(NSArray*)categories sections:(NSArray*)sections;

/**
 *  @abstract The base URL of your Zendesk knowledge base, to be used in constructing the search endpoint.
 *
 *  @discussion This value may only be set once. If the knowledgeBaseURL is not specified at init time, search is disabled.
 *
 *  The URL must be fully qualified, including http or https (ex: "https://smooch.zendesk.com").
 *
 *  The default value is nil.
 */
@property(nonatomic, copy) NSString* knowledgeBaseURL;

/**
 *  @abstract A boolean property that indicates whether to enable the app-wide gesture (two-finger swipe down) to present the Smooch UI.
 *
 *  @discussion Use option shift (⌥⇧) drag to perform the gesture on the simulator.
 *
 *  The default value is YES.
 */
@property BOOL enableAppWideGesture;

/**
 *  @abstract A boolean property that indicates whether to show a hint on how to perform the app-wide gesture when Smooch is launched for the first time (without using the gesture).
 *
 *  @discussion The default value is YES.
 */
@property BOOL enableGestureHintOnFirstLaunch;

/**
 *  @abstract A Boolean property that indicates whether to restyle webpages in full-screen article view, and recommendations cards.
 *
 *  @discussion If YES, SmoochHelpKit will inject additional css to make Zendesk Help Center articles easier to read on mobile, and also to remove the navigation header and comments footer.
 *
 *  Set this property to NO if you do not use Zendesk-based recommendations and search.
 *
 *  The default value is YES.
 */
@property BOOL enableZendeskArticleRestyling;

@end
