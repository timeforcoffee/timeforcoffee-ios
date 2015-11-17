//
//  SHKPulsingCircleView.m
//  Smooch
//
//  Created by Jean-Philippe Joyal on 5/7/14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKPulsingCircleContainerView.h"
#import "SHKAppColorExtractor.h"

@interface SHKPulsingCircleContainerView()

@property NSMutableArray* circles;

@end

@implementation SHKPulsingCircleContainerView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self initCenterCircle];
        _circles = [NSMutableArray new];
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (void)pulseXTimes:(int)times{
    [self addCircle];
    for (int i = 1; i <= times-1; i++){
        [self performSelector:@selector(addCircle) withObject:nil afterDelay:0.8 * i];
    }
}

- (void)initCenterCircle{
    UIView* circle = [self circleShapeWithRadius:14 withLineWidth:1.0f];
    [self addSubview:circle];
}

- (void) addCircle{
    SHKPulsingCircleView* circle = [[SHKPulsingCircleView alloc] initWithFrame:self.bounds withContainer:self];
    [self addSubview:circle];
    [_circles addObject:circle];
    [circle animate];
}

- (UIView*) circleShapeWithRadius:(int)radius withLineWidth:(CGFloat)width{
    UIView* circleView = [UIView new];
    circleView.frame = self.bounds;
    CAShapeLayer* circle = [SHKPulsingCircleView circleShapeWithRadius:radius withFrame:circleView.frame];
    
    circle.fillColor = [self getInnerCircleBackgroundColor];
    circle.lineWidth = 1.0f;
    
    [circleView.layer addSublayer:circle];
    
    return circleView;
}

- (CGColorRef)getInnerCircleBackgroundColor{
    UIColor *color = [SHKAppColorExtractor sharedInstance].saturatedPrimaryColor;
    CGFloat hue, saturation, brightness, alpha;
    [color getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
    
    brightness = 0.8;
    
    alpha = 0.5;
    color = [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
    return color.CGColor;
}

- (void) removeCircle:(SHKPulsingCircleView*)circle{
    [self.circles removeObject:circle];
}



@end
