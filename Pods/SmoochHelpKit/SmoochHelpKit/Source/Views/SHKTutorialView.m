//
//  SHKTutorialView.m
//  Smooch
//
//  Created by Dominic Jodoin on 2/24/2014.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKTutorialView.h"
#import "SHKTutorialOverlayView.h"
#import "SHKUtility.h"
#import "SHKLocalization.h"
#import "SmoochHelpKit+Private.h"

@interface SHKTutorialView()

@property NSTimer* handAnimationTimer;
@property SHKTutorialOverlayView* overlayView;
@property UIImageView* fingerView;

@end

@implementation SHKTutorialView

static const int ySkipButtonOffset = 10;
static const int xSkipButtonOffset = 10;

static const int yHandOffset = 50;
static const int xHandOffset = 17;

static const int handAnimationResetDuration = 3.5;

-(id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        
        self.overlayView = [[SHKTutorialOverlayView alloc] initWithFrame:frame];
        [self addSubview:self.overlayView];
        
        UIImage* handImage = [SmoochHelpKit getImageFromResourceBundle:@"shk-hand"];
        self.fingerView = [[UIImageView alloc] initWithImage:handImage];
        self.fingerView.alpha = 0;
        [self addSubview:self.fingerView];
        
        self.skipButton = [[UIButton alloc] init];
        [self.skipButton setTitle:[SHKLocalization localizedStringForKey:@"Skip"] forState:UIControlStateNormal];
        [self.skipButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.skipButton.alpha = 0.5;
        [self.skipButton sizeToFit];
        [self addSubview:self.skipButton];
    }
    
    return self;
}

-(void)startAnimation
{
    [self stopAnimationLoop];
    [self startAnimationLoop];
}

-(void)cancelAnimation
{
    [self stopAnimationLoop];
    [self fadeOutHand];
}

-(void)setHidden:(BOOL)hidden
{
    if(hidden){
        [self stopAnimationLoop];
    }
    [super setHidden:hidden];
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    self.overlayView.frame = self.bounds;
    
    CGRect frame = self.skipButton.frame;
    frame.origin.x = self.bounds.size.width - xSkipButtonOffset - frame.size.width;
    frame.origin.y = self.bounds.size.height - ySkipButtonOffset - frame.size.height;
    self.skipButton.frame = frame;
    
    self.fingerView.center = CGPointMake(self.center.x + xHandOffset, SHKNavBarHeight() + yHandOffset);
}

-(void)startAnimationLoop
{
    [self startAnimatingHandGesture];
    self.handAnimationTimer = [NSTimer scheduledTimerWithTimeInterval:handAnimationResetDuration
                                                               target:self
                                                             selector:@selector(startAnimatingHandGesture)
                                                             userInfo:nil
                                                              repeats:YES];
}

-(void)stopAnimationLoop
{
    if(self.handAnimationTimer){
        [self.handAnimationTimer invalidate];
        self.handAnimationTimer = nil;
        [self.layer removeAllAnimations];
    }
}

-(void)startAnimatingHandGesture
{
    self.fingerView.alpha = 1.0;
    self.fingerView.center = CGPointMake(self.center.x + xHandOffset, SHKNavBarHeight() + yHandOffset);
    [self fadeInHand];
}

-(void)fadeInHand
{
    [UIView animateWithDuration:0.3
                          delay:0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         self.fingerView.alpha = 1.0f;
                     } completion:^(BOOL finished){
                         if(finished){
                             [self dragHand];
                         }
                     }];
    
}

-(void)dragHand
{
    [UIView animateWithDuration:2.0f
                          delay:0.6
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         self.fingerView.center = CGPointMake(self.center.x + xHandOffset, self.bounds.size.height*0.48);
                     } completion:^(BOOL finished){
                         if(finished){
                             [self fadeOutHand];
                         }
                     }];
    
}

-(void)fadeOutHand
{
    [UIView animateWithDuration:0.3f
                          delay:0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         self.fingerView.alpha = 0;
                     } completion:nil];
}

@end
