//
//  SHKViewAboveKeyboard.m
//  Smooch
//
//  Created by Mike Spensieri on 2014-08-07.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKViewAboveKeyboard.h"
#import "SHKUtility.h"

@interface SHKViewAboveKeyboard()

@property CGSize lastKnownKeyboardSize;

@end

@implementation SHKViewAboveKeyboard

-(id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self){
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardShown:) name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardHidden:) name:UIKeyboardWillHideNotification object:nil];
    }
    return self;
}

-(void)animateReframe:(CGFloat)keyboardHeight
{
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:self.keyboardAnimationDuration];
    [UIView setAnimationCurve:self.keyboardAnimationCurve];
    [UIView setAnimationBeginsFromCurrentState:YES];
    
    [self reframe:keyboardHeight];
    
    [UIView commitAnimations];
}

-(void)reframe:(CGFloat)keyboardHeight
{
    // Override!
}

-(void)reframeAnimated:(BOOL)animated
{
    [self reframeAnimated:animated withOrientation:[UIApplication sharedApplication].statusBarOrientation];
}

-(void)reframeAnimated:(BOOL)animated withOrientation:(UIInterfaceOrientation)orientation
{
    CGFloat keyboardHeight = [self getKeyboardHeightWithOrientation:orientation];
    
    if(animated && !self.disableAnimation){
        [self animateReframe:keyboardHeight];
    }else{
        [self.layer removeAllAnimations];
        [self reframe:keyboardHeight];
    }
}

-(void)keyboardShown:(NSNotification*)notification
{
    // Mimic the keyboard's animation
    self.keyboardAnimationDuration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    self.keyboardAnimationCurve = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] intValue];
    
    // Rectangles representing the start and end frames of the keyboard
    CGRect keyboardEndRect   = [(notification.userInfo)[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect screenRect        = [[UIScreen mainScreen] bounds];
    
    // Check that the keyboard is off the screen
    if (floor(keyboardEndRect.origin.y) == floor(screenRect.size.height) ||
        floor(keyboardEndRect.origin.x) == floor(screenRect.size.width)) { // iOS 7 & below in landscape mode
        self.lastKnownKeyboardSize = CGSizeZero;
    } else if(floor(keyboardEndRect.origin.y) + self.bounds.size.height == screenRect.size.height ||
              (!SHKIsIOS8OrLater() && floor(keyboardEndRect.origin.x) + self.bounds.size.height == screenRect.size.width)){
        // Only the accessory view is onscreen, the keyboard is not shown
        self.lastKnownKeyboardSize = CGSizeZero;
    } else {
        self.lastKnownKeyboardSize = keyboardEndRect.size;
    }
    
    [self reframeAnimated:YES];
}

-(void)keyboardHidden:(NSNotification*)notification
{
    self.lastKnownKeyboardSize = CGSizeZero;
    
    [self reframeAnimated:YES];
}

-(CGFloat)getKeyboardHeightWithOrientation:(UIInterfaceOrientation)orientation
{
    if(!SHKIsIOS8OrLater() && UIInterfaceOrientationIsLandscape(orientation)){
        return self.lastKnownKeyboardSize.width;
    }else{
        return self.lastKnownKeyboardSize.height;
    }
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
