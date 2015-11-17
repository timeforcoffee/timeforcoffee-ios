//
//  SHKTableBackgroundView.m
//  Smooch
//
//  Created by Michael Spensieri on 3/4/14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKTableBackgroundView.h"
#import "SHKGradientView.h"
#import "SHKUtility.h"

@interface SHKTableBackgroundView()

@property SHKGradientView* gradient;
@property UIView* whiteWashView;

@end

@implementation SHKTableBackgroundView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self initializator];
    }
    return self;
}

-(void)initializator
{
    [self initGradient];
    [self initWhiteWashView];
}

-(void)initGradient
{
    if(!SHKIsIOS8OrLater()){
        self.gradient = [[SHKGradientView alloc] init];
        
        [self addSubview:self.gradient];
    }
}

-(void)initWhiteWashView
{
    if(SHKIsIOS8OrLater()){
        UIBlurEffect* blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight];
        self.whiteWashView = [[UIVisualEffectView alloc] initWithEffect:blur];
    }else{
        self.whiteWashView = [UIView new];
        self.whiteWashView.backgroundColor = [UIColor whiteColor];
        self.whiteWashView.alpha = 0.6;
    }
    [self addSubview:self.whiteWashView];
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    self.whiteWashView.frame = CGRectMake(0, self.bounds.origin.y + SHKNavBarHeight(), self.bounds.size.width, self.window.rootViewController.view.bounds.size.height);
    self.gradient.frame = self.bounds;
}

@end
