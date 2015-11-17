//
//  SHKDropShadowView.m
//  Smooch
//
//  Created by Joel Simpson on 2/19/2014.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKDropShadowView.h"
#import "SHKNavigationViewController.h"

@interface SHKDropShadowView()

@property CALayer* shadowLayer;

@end

@implementation SHKDropShadowView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        [self initShadowLayer];
    }
    return self;
}

-(void)initShadowLayer
{
    self.shadowLayer = [CALayer new];
    self.shadowLayer.masksToBounds = NO;
    self.shadowLayer.shadowColor = [UIColor blackColor].CGColor;
    self.shadowLayer.shadowOffset = CGSizeMake(0.0f, 0.0f);
    self.shadowLayer.shadowOpacity = 0.2f;
    self.shadowLayer.shadowRadius = 10.0f;
    self.shadowLayer.shouldRasterize = YES;
    [self reframeShadowLayer];
    
    [self.layer addSublayer:self.shadowLayer];
}

-(void)reframeShadowLayer
{
    self.shadowLayer.transform = CATransform3DIdentity;
    self.shadowLayer.frame = self.bounds;
    self.shadowLayer.anchorPoint = CGPointMake(0.5, 0.5);
    self.shadowLayer.position = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
    self.shadowLayer.shadowPath = [UIBezierPath bezierPathWithRect:self.bounds].CGPath;
}

-(void)resizeAnimated:(BOOL)animated
{
    if(!animated){
        // Disable the default CALayer animation
        // http://stackoverflow.com/questions/10845720/how-to-change-a-calayers-default-animation-time
        [CATransaction begin];
        [CATransaction setAnimationDuration: 1.0/30.0];
        [CATransaction setDisableActions: TRUE];
    }
    
    self.shadowLayer.transform = CATransform3DMakeAffineTransform([UIApplication sharedApplication].delegate.window.transform);
    
    if(!animated){
        [CATransaction commit];
    }
}

-(void)reframe:(CGRect) frame
{
    if(CGRectEqualToRect(self.frame, frame)){
        return;
    }
    self.frame = frame;
    [self reframeShadowLayer];
}

@end
