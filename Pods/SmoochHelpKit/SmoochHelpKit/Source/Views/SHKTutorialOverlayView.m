//
//  SHKTutorialOverlayView.m
//  Smooch
//
//  Created by Dominic Jodoin on 2/27/2014.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKTutorialOverlayView.h"
#import "SHKLocalization.h"
#import "SHKUtility.h"

@interface SHKTutorialOverlayView ()

@property UIView* gradientView;
@property UILabel* textTitle;
@property UILabel* textLabel;

@end

@implementation SHKTutorialOverlayView

- (void)initGradientView
{
    self.gradientView = [[UIView alloc] initWithFrame:self.bounds];
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = self.gradientView.bounds;
    UIColor * darkGradientColor = [UIColor colorWithRed:28.0/255.0 green:28.0/255.0 blue:28.0/255.0 alpha:1];
    gradient.colors = @[(id)[[UIColor clearColor] CGColor], (id)[[darkGradientColor colorWithAlphaComponent:0.9] CGColor] , (id)[darkGradientColor CGColor],(id)[darkGradientColor CGColor]];
    gradient.locations = @[@0.2f,
        @0.7f,
        @0.96f,
        @1.0f];
    [self.gradientView.layer insertSublayer:gradient atIndex:0];
    [self addSubview:self.gradientView];
    [self sendSubviewToBack:self.gradientView];
}

- (void)initTextTitle
{
    self.textTitle = [[UILabel alloc] initWithFrame:CGRectMake(45, self.bounds.size.height - 120, 230, 25)];
    self.textTitle.text = [SHKLocalization localizedStringForKey:@"Quick Tip"];
    self.textTitle.font = [UIFont boldSystemFontOfSize:20];
    self.textTitle.textColor = [UIColor whiteColor];
    self.textTitle.textAlignment = NSTextAlignmentCenter;
    self.textTitle.numberOfLines = 0;
    self.textTitle.backgroundColor = [UIColor clearColor];
    [self addSubview:self.textTitle];
}

- (void)initTextLabel
{
    self.textLabel = [[UILabel alloc] initWithFrame:CGRectMake(45, self.bounds.size.height - 105, 230, 60)];
    self.textLabel.text = [SHKLocalization localizedStringForKey:@"Swipe down with two fingers to get help from anywhere. Try it above."];
    self.textLabel.font= [UIFont systemFontOfSize:14];
    self.textLabel.textColor = [UIColor whiteColor];
    self.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.textLabel.textAlignment = NSTextAlignmentCenter;
    self.textLabel.numberOfLines = 0;
    self.textLabel.backgroundColor = [UIColor clearColor];
    [self addSubview:self.textLabel];
}

-(id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self initGradientView];
        [self initTextTitle];
        [self initTextLabel];
    }
    
    return self;
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    self.gradientView.frame = self.bounds;
    self.textTitle.frame = CGRectMake(45, self.bounds.size.height - 120, 230, 25);
    self.textTitle.center = CGPointMake(self.center.x, self.textTitle.center.y);
    self.textLabel.frame = CGRectMake(45, self.bounds.size.height - 105, 230, 60);
    self.textLabel.center = CGPointMake(self.center.x, self.textLabel.center.y);
    
    [self.gradientView removeFromSuperview];
    [self initGradientView];
}


@end
