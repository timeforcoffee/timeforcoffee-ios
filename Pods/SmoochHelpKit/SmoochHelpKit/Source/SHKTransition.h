//
//  SHKTransition.h
//  Smooch
//
//  Created by Mike on 2014-05-13.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SHKStateMachine.h"
@class SHKOffsetManager;

@interface SHKTransition : NSObject

-(instancetype)initWithSourceState:(SmoochState)sourceState offsetManager:(SHKOffsetManager*)offsetManager;

-(void)addOffset:(CGFloat)offset;
-(void)transitionTo:(SmoochState)state withCompletion:(void (^)(SmoochState outputState))completion;
-(void)autoTransitionWithCompletion:(void (^)(SmoochState outputState))completion;

@property SmoochState sourceState;

@end
