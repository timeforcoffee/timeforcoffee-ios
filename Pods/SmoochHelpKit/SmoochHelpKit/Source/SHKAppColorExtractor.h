//
//  SHKAppColorExtractor.h
//  Smooch
//
//  Created by Jean-Philippe Joyal on 2/26/14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

extern NSString* const SHKAppColorUpdatedNotification;

@interface SHKAppColorExtractor : NSObject

+ (SHKAppColorExtractor*) sharedInstance;

- (BOOL) hasAppColors;
- (void) extractAppColors;

@property(readonly) UIColor* primaryAppColor;
@property(readonly) UIColor* secondaryAppColor;

@property(readonly) UIColor* lightenedPrimaryColor;
@property(readonly) UIColor* lightenedSecondaryColor;

@property(readonly) UIColor* darkenedPrimaryColor;
@property(readonly) UIColor* saturatedPrimaryColor;

@end
