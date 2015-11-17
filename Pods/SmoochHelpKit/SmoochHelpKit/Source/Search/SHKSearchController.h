//
//  SHKSearchController.h
//  Smooch
//
//  Created by Mike on 2014-05-06.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
@class SHKSearchFallbackStrategy;
@class SHKSearchResult;
@class SHKSettings;

extern NSString* const SHKSearchControllerResultsDidChangeNotification;
extern NSString* const SHKSearchStartedNotification;
extern NSString* const SHKSearchCancelledNotification;
extern NSString* const SHKSearchCompleteNotification;

@interface SHKSearchController : NSObject

+(instancetype)searchControllerWithSettings:(SHKSettings*)settings;

-(instancetype)initWithStrategy:(SHKSearchFallbackStrategy*)strategy;

-(void)search:(NSString*)searchText;
-(void)cancelCurrentRequest;
-(SHKSearchResult*)searchResultAtIndex:(NSInteger)index;

@property NSArray* searchResults;
@property NSError* error;

@end

