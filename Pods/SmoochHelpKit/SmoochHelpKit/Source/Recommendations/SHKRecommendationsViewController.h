//
//  SHKRecommendationsViewController.h
//  Smooch
//
//  Created by Joel Simpson on 2014-04-17.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SHKRecommendationsManager.h"

extern NSString* const SHKRecommendationsViewControllerReachedEndOfRecommandation;
extern NSString* const SHKRecommendationsViewControllerReachedSecondToLastRecommendation;

@interface SHKRecommendationsViewController : UIViewController < SHKRecommendationsManagerDelegate >

-(void)resetSwipeViewToStart;

@property SHKRecommendationsManager* recommendationsManager;

@end
