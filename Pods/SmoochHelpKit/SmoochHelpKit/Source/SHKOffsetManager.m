//
//  SHKOffsetManager.m
//  Smooch
//
//  Created by Mike on 2014-05-15.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKOffsetManager.h"
#import "SmoochHelpKit+Private.h"
#import "SHKOverlayWindow.h"

NSString* const SHKOffsetManagerDidChangePercentageNotification = @"SHKOffsetManagerDidChangePercentageNotification";

static const CGFloat kDurationForBounceAnimation = 0.25;
static const CGFloat kDurationForZoomAnimation = 0.2;
static const CGFloat kBounceAdditionalPercentage = 0.5;

const CGFloat SHKOffsetManagerInactivePercentage = 0.0;
const CGFloat SHKOffsetManagerActivePercentage = 1.0;
const CGFloat SHKOffsetManagerSemiActivePercentage = 0.2;
const CGFloat SHKOffsetManagerMiniaturePercentage = 2.0;

@implementation SHKOffsetManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.offsetPercentage = 0;
        self.activeStateSnapPercentage = SHKOffsetManagerActivePercentage;
    }
    return self;
}

-(CGFloat)bouncePercentage
{
    return _activeStateSnapPercentage + kBounceAdditionalPercentage;
}

-(BOOL)shouldBounce
{
    return self.offsetPercentage <= self.activeStateSnapPercentage;
}

-(void)animateToPercentage:(CGFloat)percentage isDragging:(BOOL)isDragging withCompletion:(void (^)(void))completion
{
    CGFloat originalPercentage = self.offsetPercentage;
    self.offsetPercentage = MAX(0, percentage);
    
    if(isDragging){
        [[NSNotificationCenter defaultCenter] postNotificationName:SHKOffsetManagerDidChangePercentageNotification object:self userInfo:@{ @"dragging" : @YES }];
        if(completion){
            completion();
        }
        return;
    }
    
    CGFloat animationDuration = kDurationForZoomAnimation;
    
    if(self.offsetPercentage == SHKOffsetManagerActivePercentage && originalPercentage > SHKOffsetManagerActivePercentage){
        // We're bouncing back to zero
        animationDuration = kDurationForBounceAnimation;
    }
    
    [UIView animateWithDuration:animationDuration
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         // Disable user interaction while animating
                         // If not, the user can tap close before transition completes, resulting in broken UI
                         [SmoochHelpKit overlayWindow].userInteractionEnabled = NO;
                         
                         [[NSNotificationCenter defaultCenter] postNotificationName:SHKOffsetManagerDidChangePercentageNotification object:self];
                     } completion:^(BOOL finished){
                         [SmoochHelpKit overlayWindow].userInteractionEnabled = YES;
                         if(completion && finished){
                             completion();
                         }
                     }];
}

@end
