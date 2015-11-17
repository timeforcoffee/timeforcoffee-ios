//
//  SHKAppWideGestureHandler.h
//  Smooch
//
//  Created by Mike on 2014-05-13.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
@class SHKStateMachine;

@protocol SHKAppWideGestureHandlerDelegate;

@interface SHKAppWideGestureHandler : NSObject < UIGestureRecognizerDelegate >

-(instancetype)initWithStateMachine:(SHKStateMachine*)stateMachine;

-(void)addAppWideGestureTo:(UIWindow*)window;
-(void)removeAppWideGesture;

@property(weak) id<SHKAppWideGestureHandlerDelegate> delegate;

@end

@protocol SHKAppWideGestureHandlerDelegate <NSObject>

-(BOOL)appWideGestureHandlerShouldBeginGesture:(SHKAppWideGestureHandler*)gestureHandler;

@end
