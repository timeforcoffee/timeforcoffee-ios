//
//  SHKRecommendationPreviewView.m
//  Smooch
//
//  Created by Michael Spensieri on 4/16/14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKRecommendationPreviewView.h"
#import "SHKVerticalProgressView.h"
#import "SmoochHelpKit+Private.h"
#import "SHKAppColorExtractor.h"

@implementation SHKRecommendationPreviewView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.loadingBar = [SHKVerticalProgressView new];
        [self addSubview:self.loadingBar];
        
        self.layer.masksToBounds = NO;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOffset = CGSizeMake(0.0f, 0.0f);
        self.layer.shadowOpacity = 0.10f;
        self.layer.shadowRadius = 10.0f;
        self.layer.shouldRasterize = YES;
        
        [self updateBackgroundColor];
        
        self.contentMode = UIViewContentModeScaleToFill;
        
        self.image = [SmoochHelpKit getImageFromResourceBundle:@"shk-recommendation-placeholder"];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateBackgroundColor) name:SHKAppColorUpdatedNotification object:nil];
    }
    return self;
}

-(void)updateBackgroundColor
{
    self.backgroundColor = [self colorByLighteningColor:[SHKAppColorExtractor sharedInstance].primaryAppColor];
}

- (UIColor*)colorByLighteningColor:(UIColor*)color
{
    CGFloat hue, saturation, brightness, alpha;
    [color getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
    
    if(saturation > 0.25)
        saturation = 0.25;
    
    brightness = 0.90;
    
    return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    self.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.bounds].CGPath;
    self.loadingBar.frame = CGRectMake(-4, 0, 4, self.bounds.size.height);
}

-(void)crossfadeToImage:(UIImage *)image
{
    CABasicAnimation *crossFade = [CABasicAnimation animationWithKeyPath:@"contents"];
    crossFade.duration = 0.25;
    crossFade.fromValue = (__bridge id)(self.image.CGImage);
    crossFade.toValue = (__bridge id)(image.CGImage);
    
    [self.layer addAnimation:crossFade forKey:kCATransition];
    
    self.image = image;
}

-(void)markAsFailed
{
    self.image = [SmoochHelpKit getImageFromResourceBundle:@"shk-recommendation-failed"];
    self.contentMode = UIViewContentModeCenter;
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
