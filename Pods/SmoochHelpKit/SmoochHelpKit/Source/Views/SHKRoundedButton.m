//
//  SHKRoundedButton.m
//  Smooch
//
//  Created by Jean-Philippe Joyal on 11/15/13.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKRoundedButton.h"
#import "SHKUtility.h"
#import "SHKAppColorExtractor.h"

static const int buttonSidePadding = 40;

@implementation SHKRoundedButton

+(SHKRoundedButton*) new{
    SHKRoundedButton* button = [self buttonWithType:UIButtonTypeCustom];
    button.layer.cornerRadius = 18.0;
    button.layer.masksToBounds = YES;
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button setTitleColor:[UIColor colorWithRed:136/255.0 green:136/255.0 blue:136/255.0 alpha:1] forState:UIControlStateHighlighted];
    button.titleLabel.font = [UIFont systemFontOfSize:15];
    
    button.imageEdgeInsets = UIEdgeInsetsMake(3, 0, 0, 10);
    
    [[NSNotificationCenter defaultCenter] addObserver:button selector:@selector(updateButtonColor) name:SHKAppColorUpdatedNotification object:nil];
    [button updateButtonColor];
    return button;
}

-(void)updateButtonColor{
    if ([[SHKAppColorExtractor sharedInstance] hasAppColors]) {
        self.backgroundColor = [SHKAppColorExtractor sharedInstance].darkenedPrimaryColor;
    }else{
        //default green color
        self.backgroundColor = [UIColor colorWithRed:83.0/255.0 green:215.0/255.0 blue:105.0/255.0 alpha:1.0];
    }
}

- (UIColor*)colorByModifyingColor:(UIColor*)color
{
    CGFloat hue, saturation, brightness, alpha;
    [color getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
    
    // make it dark
    saturation = 0.24;
    brightness = 0.18;
    alpha = 0.85;
    
    return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
}

- (CGSize)sizeThatFits:(CGSize)size{
    CGSize newSize = [super sizeThatFits:size];
    newSize.width = newSize.width + buttonSidePadding;
    newSize.height = size.height;
    return newSize;
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
