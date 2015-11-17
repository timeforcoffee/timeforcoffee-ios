//
//  SHKViewAboveKeyboard.h
//  Smooch
//
//  Created by Mike Spensieri on 2014-08-07.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SHKViewAboveKeyboard : UIView

-(void)reframeAnimated:(BOOL)animated;
-(void)reframeAnimated:(BOOL)animated withOrientation:(UIInterfaceOrientation)orientation;

@property double keyboardAnimationDuration;
@property int keyboardAnimationCurve;
@property BOOL disableAnimation;

@end

@interface SHKViewAboveKeyboard(Overrides)

-(void)animateReframe:(CGFloat)keyboardHeight;
-(void)reframe:(CGFloat)keyboardHeight;
-(CGFloat)getKeyboardHeightWithOrientation:(UIInterfaceOrientation)orientation;
-(void)keyboardShown:(NSNotification*)notification;
-(void)keyboardHidden:(NSNotification*)notification;

@end
