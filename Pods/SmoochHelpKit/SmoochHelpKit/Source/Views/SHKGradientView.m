//
//  SHKGradientView.m
//  Smooch
//
//  Created by Joel Simpson on 2/4/2014.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKGradientView.h"
#import "SHKUtility.h"
#import "SHKAppColorExtractor.h"

@interface SHKGradientView()

@end

@implementation SHKGradientView

-(id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self){
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setGradientColors) name:SHKAppColorUpdatedNotification object:nil];
    }
    return self;
}

-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setGradientColors
{
    [self setNeedsDisplay];
    // animate the transition
    [UIView transitionWithView:self duration:0.5
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        [self.layer displayIfNeeded];
                    } completion:nil];
}

- (void)drawRect:(CGRect)rect
{
    if(![[SHKAppColorExtractor sharedInstance] hasAppColors]){
        [super drawRect:rect];
    }else{
        CGContextRef ref = UIGraphicsGetCurrentContext();
        
        UIColor* color1 = [SHKAppColorExtractor sharedInstance].lightenedPrimaryColor;
        UIColor* color2 = [SHKAppColorExtractor sharedInstance].lightenedSecondaryColor;
        
        NSArray* array;
        // More colorful color goes on the bottom
        array = @[(id)[color2 CGColor], (id)[color1 CGColor]];
        
        CFArrayRef colors = (__bridge CFArrayRef)array;

        CGColorSpaceRef colorSpc = CGColorSpaceCreateDeviceRGB();
        
        CGFloat locations[2] = {0.0, 1.0};
        CGGradientRef gradient = CGGradientCreateWithColors(colorSpc, colors, locations);
        
        CGContextDrawLinearGradient(ref, gradient, CGPointMake(0.0, 0.0), CGPointMake(0.0, rect.size.height), kCGGradientDrawsAfterEndLocation);
        CGColorSpaceRelease(colorSpc);
        CGGradientRelease(gradient);
    }
}

@end
