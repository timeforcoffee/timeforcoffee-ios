//
//  SHKWindow.h
//  Smooch
//
//  Created by Michael Spensieri on 2/24/14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
@class SHKTransition;

extern NSString* const SmoochWindowResizingNotification;

@interface SHKWindow : UIWindow

-(void)smoochDidBeginTransition:(SHKTransition*)transition;
-(void)smoochDidBecomeInactive;
-(void)smoochDidBecomeSemiActive;
-(void)smoochDidBecomeActive;

-(void)appWillChangeStatusBarHeight;
-(void)appDidChangeStatusBarHeight;

@end
