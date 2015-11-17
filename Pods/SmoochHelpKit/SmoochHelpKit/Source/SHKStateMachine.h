//
//  SHKStateMachine.h
//  Smooch
//
//  Created by Mike on 2014-05-14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
@class SHKTransition;
@class SHKOffsetManager;

typedef NS_ENUM(NSInteger, SmoochState) {
    SmoochStateInactive,
    SmoochStateTransitioning,
    SmoochStateSemiActive,
    SmoochStateActive,
} ;

extern NSString* const SHKStateMachineDidEnterSemiActiveStateNotification;
extern NSString* const SHKStateMachineDidEnterTransitioningStateNotification;
extern NSString* const SHKStateMachineDidEnterActiveStateNotification;
extern NSString* const SHKStateMachineDidEnterInactiveStateNotification;

@protocol SHKStateMachineDelegate;

@interface SHKStateMachine : NSObject

+(instancetype)sharedInstance;
+(SmoochState)currentState;
+(CGFloat)currentPercentage;

-(void)transitionToState:(SmoochState)newState;
-(void)transitionToState:(SmoochState)newState withCompletion:(void (^)(void))completion;
-(void)completeActiveTransition;

@property(weak) id<SHKStateMachineDelegate> delegate;
@property SmoochState currentState;
@property SHKTransition* transition;
@property SHKOffsetManager* offsetManager;

@end

@protocol SHKStateMachineDelegate <NSObject>

-(BOOL)stateMachine:(SHKStateMachine*)stateMachine shouldChangeToState:(SmoochState)state;

@end
