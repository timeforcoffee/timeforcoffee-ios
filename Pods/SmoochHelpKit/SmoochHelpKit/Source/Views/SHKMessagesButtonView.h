//
//  SHKMessagesButtonView.h
//  Smooch
//
//  Created by Jean-Philippe Joyal on 11/14/13.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SHKViewAboveKeyboard.h"

@protocol SHKMessagesButtonPositioningDelegate;

@interface SHKMessagesButtonView : SHKViewAboveKeyboard

-(instancetype)initWithTarget:(id)target action:(SEL)action;

+(CGFloat)getHeightNeededForButton;
+(CGFloat)getButtonMinYCoordinate;

@property(weak) id<SHKMessagesButtonPositioningDelegate> positioningDelegate;

@end

@protocol SHKMessagesButtonPositioningDelegate <NSObject>

-(BOOL)messagesButtonView:(SHKMessagesButtonView*)messagesButton shouldMoveAboveKeyboardWithHeight:(CGFloat)keyboardHeight orientation:(UIInterfaceOrientation)orientation;

@end
