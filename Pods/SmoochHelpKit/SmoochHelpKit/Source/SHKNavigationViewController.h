//
//  SHKNavigationViewController.h
//  Smooch
//
//  Created by Michael Spensieri on 11/25/13.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SHKAppWideGestureHandler.h"
#import "SHKStateMachine.h"
#import "SHKMessagesButtonView.h"

@class SHKMessagesButtonView;

@interface SHKNavigationViewController : UINavigationController < UINavigationControllerDelegate, SHKAppWideGestureHandlerDelegate, SHKStateMachineDelegate >

-(void)showGestureHint;
-(void)cancelGestureHint;

-(void)showArticle:(NSString*)url;

-(void)endEditing;

@property SHKMessagesButtonView* messagesButton;

@property (NS_NONATOMIC_IOSONLY, readonly) BOOL conversationOnly;

@end

