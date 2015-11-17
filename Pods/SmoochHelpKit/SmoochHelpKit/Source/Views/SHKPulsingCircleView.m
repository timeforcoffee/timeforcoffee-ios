//
//  SHKCircleView.m
//  Smooch
//
//  Created by Jean-Philippe Joyal on 5/8/14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKPulsingCircleView.h"
#import "SHKAppColorExtractor.h"
#import "SHKPulsingCircleContainerView.h"

@interface SHKPulsingCircleView()

@property UIView* circleView;
@property SHKPulsingCircleContainerView* container;

@end

@implementation SHKPulsingCircleView

+ (CAShapeLayer*) circleShapeWithRadius:(int)radius withFrame:(CGRect)frame{

    CAShapeLayer* circle = [CAShapeLayer layer];
    circle.path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 2.0*radius, 2.0*radius)
                                             cornerRadius:radius].CGPath;
    //Center the shape in given frame
    circle.position = CGPointMake(CGRectGetMidX(frame)-radius,
                                  CGRectGetMidY(frame)-radius);
    
    // default apperence
    circle.fillColor = [UIColor clearColor].CGColor;
    circle.lineWidth = 2.0f;
    // gray as default
    circle.strokeColor = [UIColor colorWithRed:172.0/255.0 green:172.0/255.0 blue:172.0/255.0 alpha:1.0].CGColor;
    
    return circle;
}

- (id)initWithFrame:(CGRect)frame withContainer:(SHKPulsingCircleContainerView*) container
{
    self = [super initWithFrame:frame];
    if (self) {
        self.container = container;
        [self initCircleWithRadius:30 withInitialScale:0.1666f];
    }
    return self;
}

- (void) initCircleWithRadius:(int) radius withInitialScale:(CGFloat)scale{
    
    _circleView = [UIView new];
    _circleView.frame = self.bounds;
    
    CAShapeLayer* circle = [self.class circleShapeWithRadius:radius withFrame:_circleView.frame];
    
    circle.strokeColor = [SHKAppColorExtractor sharedInstance].saturatedPrimaryColor.CGColor;
    
    [_circleView.layer addSublayer:circle];
    
    [self setCircleViewScale:scale];
    
    [self addSubview:_circleView];
}

-(void) animate{
    [self animateToScale:1.5f withCompletionBlock:^(void){
        [self removeFromSuperview];
        [self.container removeCircle:self];
    }];
}

- (void)animateToScale:(CGFloat) scale withCompletionBlock:(void (^)(void))block
{
    [UIView animateWithDuration:1.0f
                          delay:0.0f
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         [self setCircleViewScale:scale];
                         self.alpha = 0;
                     }
                     completion:^(BOOL finished){
                         if(block && finished) {
                             block();
                         }
                     }];
}
- (void)setCircleViewScale:(CGFloat) scale{
    _circleView.transform = CGAffineTransformMakeScale(scale, scale);
}


@end
