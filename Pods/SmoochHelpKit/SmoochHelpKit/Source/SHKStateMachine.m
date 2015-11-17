//
//  SHKStateMachine.m
//  Smooch
//
//  Created by Mike on 2014-05-14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKStateMachine.h"
#import "SHKTransition.h"
#import "SHKOffsetManager.h"

NSString* const SHKStateMachineDidEnterSemiActiveStateNotification = @"SHKStateMachineDidEnterSemiActiveStateNotification";
NSString* const SHKStateMachineDidEnterActiveStateNotification = @"SHKStateMachineDidEnterActiveStateNotification";
NSString* const SHKStateMachineDidEnterInactiveStateNotification = @"SHKStateMachineDidEnterInactiveStateNotification";
NSString* const SHKStateMachineDidEnterTransitioningStateNotification = @"SHKStateMachineDidEnterTransitioningStateNotification";

@interface SHKStateMachine()

@end

@implementation SHKStateMachine

@synthesize currentState = _currentState;

+(instancetype)sharedInstance
{
    static SHKStateMachine* staticInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        staticInstance = [SHKStateMachine new];
    });
    
    return staticInstance;
}

+(SmoochState)currentState
{
    return [[self sharedInstance] currentState];
}

+(CGFloat)currentPercentage
{
    return [[self sharedInstance] offsetManager].offsetPercentage;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _currentState = SmoochStateInactive;
        _offsetManager = [SHKOffsetManager new];
        _transition = [[SHKTransition alloc] initWithSourceState:_currentState offsetManager:_offsetManager];
    }
    return self;
}

-(void)setCurrentState:(SmoochState)newState
{
    if(newState == _currentState){
        return;
    }
    
    if([self.delegate respondsToSelector:@selector(stateMachine:shouldChangeToState:)]){
        if(![self.delegate stateMachine:self shouldChangeToState:newState]){
            return;
        }
    }
    
    SmoochState previousState = _currentState;
    
    _currentState = newState;
    if(newState == SmoochStateInactive){
        [[NSNotificationCenter defaultCenter] postNotificationName:SHKStateMachineDidEnterInactiveStateNotification object:self];
    }else if(newState == SmoochStateTransitioning){
        self.transition.sourceState = previousState;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:SHKStateMachineDidEnterTransitioningStateNotification object:self.transition];
    }else if(newState == SmoochStateActive){
        [[NSNotificationCenter defaultCenter] postNotificationName:SHKStateMachineDidEnterActiveStateNotification object:self];
    }else{
        [[NSNotificationCenter defaultCenter] postNotificationName:SHKStateMachineDidEnterSemiActiveStateNotification object:self];
    }
}

-(SmoochState)currentState
{
    return _currentState;
}

-(void)transitionToState:(SmoochState)newState
{
    [self transitionToState:newState withCompletion:nil];
}

-(void)transitionToState:(SmoochState)newState withCompletion:(void (^)(void))completion;
{
    if(self.currentState != SmoochStateTransitioning){
        self.currentState = SmoochStateTransitioning;
    }
    
    [self.transition transitionTo:newState withCompletion:^(SmoochState outputState) {
        self.currentState = outputState;
        if(completion){
            completion();
        }
    }];
}

-(void)completeActiveTransition
{
    [self.transition autoTransitionWithCompletion:^(SmoochState outputState) {
        self.currentState = outputState;
    }];
}
@end
