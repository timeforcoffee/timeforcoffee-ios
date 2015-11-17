//
//  SHKNoNetworkView.m
//  Smooch
//
//  Created by Michael Spensieri on 12/9/13.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKNoNetworkView.h"
#import "SmoochHelpKit+Private.h"
#import "SHKLocalization.h"

static const NSString* kSHKNoNetworkIcon = @"";

@interface SHKNoNetworkView()

@property UILabel* label;
@property UIButton* button;

@end

@implementation SHKNoNetworkView

-(id)initWithFrame:(CGRect)frame target:(id)target action:(SEL)action
{
    self = [super initWithFrame:frame];
    if (self) {
        [self initLabel];
        
        if(target && action){
            [self initButton];
            [self.button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
        }
    }
    return self;
}

-(void)initLabel
{
    self.label = [[UILabel alloc] initWithFrame:CGRectMake(0,
                                                           0,
                                                           self.bounds.size.width,
                                                           CGFLOAT_MAX)];
    self.label.font = [UIFont systemFontOfSize:17];
    self.label.textColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1];
    self.label.textAlignment = NSTextAlignmentCenter;
    self.label.numberOfLines = 0;
    
    self.label.attributedText = [self getAttributedStringForTextLabel];
    [self.label sizeToFit];
    
    self.label.center = CGPointMake(self.center.x, self.label.center.y);
    
    [self addSubview:self.label];
}

-(void)initButton
{
    self.button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.button.frame = CGRectMake(0,
                                   CGRectGetMaxY(self.label.frame),
                                   200,
                                   44);
    [self.button setTitle:[SHKLocalization localizedStringForKey:@"Reload"] forState:UIControlStateNormal];
    
    [self.button sizeToFit];
    self.button.center = CGPointMake(self.center.x, self.button.center.y);
    
    [self addSubview:self.button];
}

-(void)sizeToFit
{
    CGFloat height = CGRectGetMaxY(self.label.frame) + CGRectGetHeight(self.button.frame);
    
    self.frame = CGRectMake(0, 0, self.bounds.size.width, height);
}

-(NSAttributedString*)getAttributedStringForTextLabel
{
    NSString* labelText = [SHKLocalization localizedStringForKey:@"Cannot open the page because your device is not connected to the Internet."];
    
    UIFont* symbolFont = [UIFont fontWithName:@"ios7-icon" size:100];
    if(symbolFont == nil){
        return [[NSAttributedString alloc] initWithString:labelText];
    }
    
    NSString* fullText = [NSString stringWithFormat:@"%@\n%@", [kSHKNoNetworkIcon copy], labelText];
    NSMutableAttributedString* str = [[NSMutableAttributedString alloc] initWithString:fullText];
    [str setAttributes:@{ NSFontAttributeName : symbolFont } range:NSMakeRange(0, 1)];
    
    return str;
}

@end
