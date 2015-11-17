//
//  SHKAppWideGestureHandler.m
//  Smooch
//
//  Created by Mike on 2014-05-13.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKAppWideGestureHandler.h"
#import "SHKTwoFingerSwipeGestureRecognizer.h"
#import "SHKStateMachine.h"
#import "SHKTransition.h"

static const int kVelocityRequiredForSwipe = 1000;

@interface SHKAppWideGestureHandler()

@property SHKTwoFingerSwipeGestureRecognizer* panGesture;
@property(weak) UIWindow* currentWindow;
@property NSMutableSet* otherRecognizers;
@property SHKStateMachine* stateMachine;

@end

@implementation SHKAppWideGestureHandler

- (instancetype)initWithStateMachine:(SHKStateMachine *)stateMachine
{
    self = [super init];
    if (self) {
        self.otherRecognizers = [NSMutableSet new];
        self.stateMachine = stateMachine;
    }
    return self;
}

-(void)dealloc
{
    [_currentWindow removeGestureRecognizer:_panGesture];
}

-(void)addAppWideGestureTo:(UIWindow*)window
{
    if(!self.panGesture){
        self.panGesture = [[SHKTwoFingerSwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleGesture:)];
        self.panGesture.delegate = self;
    }
    
    [self.currentWindow removeGestureRecognizer:self.panGesture];
    [window addGestureRecognizer:self.panGesture];
    self.currentWindow = window;
}

-(void)removeAppWideGesture
{
    [self.currentWindow removeGestureRecognizer:self.panGesture];
    self.currentWindow = nil;
}

-(void)handleGesture:(SHKTwoFingerSwipeGestureRecognizer*)swipeGesture
{
    if([self.delegate respondsToSelector:@selector(appWideGestureHandlerShouldBeginGesture:)]){
        if(![self.delegate appWideGestureHandlerShouldBeginGesture:self]){
            return;
        }
    }
    
    UIGestureRecognizerState state = swipeGesture.state;
    
    if (state == UIGestureRecognizerStateFailed) {
        return;
    }
    
    if (UIGestureRecognizerStateBegan == state) {
        [self.stateMachine setCurrentState:SmoochStateTransitioning];
        
        for(UIGestureRecognizer* recognizer in self.otherRecognizers){
            // Cancel any other pan gesture (aka scroll)
            recognizer.enabled = NO;
        }
    }else if(UIGestureRecognizerStateChanged == state) {
        CGFloat verticalOffset = swipeGesture.verticalOffset;
        
        [self.stateMachine.transition addOffset:verticalOffset];
        [swipeGesture setTranslation:CGPointZero inView:swipeGesture.view];
    }else if(UIGestureRecognizerStateEnded == state || UIGestureRecognizerStateCancelled == state) {
        for(UIGestureRecognizer* recognizer in self.otherRecognizers){
            // Re-enable the gestures we disabled
            recognizer.enabled = YES;
        }
        [self.otherRecognizers removeAllObjects];
        
        CGFloat velocity = swipeGesture.verticalVelocity;
        if(velocity > kVelocityRequiredForSwipe){
            [self.stateMachine transitionToState:SmoochStateActive];
        }else if(velocity < -kVelocityRequiredForSwipe){
            [self.stateMachine transitionToState:SmoochStateInactive];
        }else{
            [self.stateMachine completeActiveTransition];
        }
    }
}

-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if([otherGestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]] && otherGestureRecognizer != self.panGesture){
        [self.otherRecognizers addObject:otherGestureRecognizer];
    }
    
    if([otherGestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]] || [otherGestureRecognizer isKindOfClass:[UIRotationGestureRecognizer class]]){
        return NO;
    }
    
    return YES;
}


@end
