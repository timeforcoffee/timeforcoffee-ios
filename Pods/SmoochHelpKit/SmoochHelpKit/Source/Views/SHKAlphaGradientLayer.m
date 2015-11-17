//
//  SHKAlphaGradientLayer.m
//  Smooch
//
//  Created by Joel Simpson on 2014-08-28.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKAlphaGradientLayer.h"
#import "SHKUtility.h"

@implementation SHKAlphaGradientLayer

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.colors = @[(id)[UIColor colorWithWhite:1.0 alpha:1.0].CGColor,
                        (id)[UIColor colorWithWhite:1.0 alpha:0.05].CGColor,
                        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor];
    }
    return self;
}

-(void)setGradientPoints
{
    [self setGradientPointsForOrientation:[UIApplication sharedApplication].statusBarOrientation];
}

-(void)setGradientPointsForOrientation:(UIInterfaceOrientation)orientation
{
    if(SHKIsIOS8OrLater()){
        orientation = UIInterfaceOrientationPortrait;
    }
    
    switch (orientation) {
        case UIInterfaceOrientationPortraitUpsideDown:
            self.startPoint = CGPointMake(0.5, SHKIsIpad() ? 0.4 : 1.0);
            self.endPoint = CGPointMake(0.5, 0);
            break;
        case UIInterfaceOrientationLandscapeLeft:
            self.startPoint = CGPointMake(0.0, 0.5);
            self.endPoint = CGPointMake(1.0, 0.5);
            break;
        case UIInterfaceOrientationLandscapeRight:
            self.startPoint = CGPointMake(1.0, 0.5);
            self.endPoint = CGPointMake(0.0, 0.5);
            break;
        default: // UIInterfaceOrientationPortrait, UIInterfaceOrientationUnknown
            self.startPoint = CGPointMake(0.5, SHKIsIpad() ? 0.6 : 0.0);
            self.endPoint = CGPointMake(0.5, 1.0);
            break;
    }
}

@end
