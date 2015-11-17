//
//  SHKTransition.m
//  Smooch
//
//  Created by Mike on 2014-05-13.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKTransition.h"
#import "SHKStateMachine.h"
#import "SHKOffsetManager.h"

static const int kMaxAllowedOffsetPerIteration = 12;

@interface SHKTransition()

@property SHKOffsetManager* offsetManager;

@end

@implementation SHKTransition

-(instancetype)initWithSourceState:(SmoochState)sourceState offsetManager:(SHKOffsetManager *)offsetManager
{
    self = [super init];
    if(self){
        self.sourceState = sourceState;
        self.offsetManager = offsetManager;
    }
    return self;
}

-(void)addOffset:(CGFloat)offset
{
    // Limit velocity
    if(offset > kMaxAllowedOffsetPerIteration){
        offset = kMaxAllowedOffsetPerIteration;
    }else if (offset < -kMaxAllowedOffsetPerIteration){
        offset = -kMaxAllowedOffsetPerIteration;
    }
    
    [self.offsetManager animateToPercentage:self.offsetManager.offsetPercentage + (offset / 100.0) isDragging:YES withCompletion:nil];
}

-(void)autoTransitionWithCompletion:(void (^)(SmoochState outputState))completion
{
    SmoochState outputState = [self outputState];
    
    [self transitionTo:outputState withCompletion:completion];
}

-(void)transitionTo:(SmoochState)state withCompletion:(void (^)(SmoochState outputState))completion
{
    if(SmoochStateInactive == state){
        [self.offsetManager animateToPercentage:SHKOffsetManagerInactivePercentage isDragging:NO withCompletion:^{
            if(completion){
                completion(SmoochStateInactive);
            }
        }];
    }else if(SmoochStateActive == state){
        if([self.offsetManager shouldBounce]){
            [self.offsetManager animateToPercentage:self.offsetManager.bouncePercentage isDragging:NO withCompletion:^{
                [self bounceUpWithCompletion:completion];
            }];
        }else{
            [self bounceUpWithCompletion:completion];
        }
    }
}

-(void)bounceUpWithCompletion:(void (^)(SmoochState outputState))completion
{
    [self.offsetManager animateToPercentage:self.offsetManager.activeStateSnapPercentage isDragging:NO withCompletion:^{
        if(completion){
            completion(SmoochStateActive);
        }
    }];
}

-(SmoochState)outputState
{
    return self.offsetManager.offsetPercentage > (SHKOffsetManagerActivePercentage / 2) ? SmoochStateActive : SmoochStateInactive;
}

@end
