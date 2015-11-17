//
//  SHKVerticalProgressView.m
//  Smooch
//
//  Created by Joel Simpson on 2014-04-11.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKVerticalProgressView.h"
#import "SHKAppColorExtractor.h"

@interface SHKVerticalProgressView()

@property float progress;
@property float margin;
@property float topMargin;
@property float bottomMargin;
@property UIView* progressBar;

@end

@implementation SHKVerticalProgressView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.margin = 5.0;
        self.topMargin = self.margin/100;
        self.bottomMargin = 1 - self.topMargin;
        self.backgroundColor = [UIColor clearColor];
        self.progressBar = [[UIView alloc] init];
        [self updateProgressBarColor];
        [self addSubview:self.progressBar];
        self.alpha = 0;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateProgressBarColor) name:SHKAppColorUpdatedNotification object:nil];
    }
    return self;
}

-(void)updateProgressBarColor
{
    self.progressBar.backgroundColor = [SHKAppColorExtractor sharedInstance].saturatedPrimaryColor;
}

-(void)start
{
    [self clearSelectors];
    self.progress = self.topMargin;
    [self fadeIn];
    [self animateProgress];
    [self trickle];
}

-(void)finish
{
    [self clearSelectors];
    self.progress = 1;
    [self animateProgress];
    [self fadeOut];
}

-(void)clearSelectors
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

-(void)trickle
{
    [self incrementProgress:((self.bottomMargin-self.progress)*0.035*drand48())];
    [self performSelector:@selector(trickle) withObject:nil afterDelay:(0.35+(0.4*drand48()))];
}

-(void)incrementProgress:(double)delta
{
    if(self.progress < self.bottomMargin)
    {
        self.progress += delta ?: 0.05;
    }
    [self animateProgress];
}

-(void)animateProgress
{
    [UIView animateWithDuration:0.5 animations:^{
        self.progressBar.frame = CGRectMake(0, 0, self.bounds.size.width, self.progress*self.bounds.size.height);
    } completion:nil];
}

-(void)fadeIn
{
    [UIView animateWithDuration:0.5 animations:^{
        self.alpha = 1;
    } completion:nil];
}

-(void)fadeOut
{
    [UIView animateWithDuration:0.5 animations:^{
        self.alpha = 0;
    } completion:nil];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end