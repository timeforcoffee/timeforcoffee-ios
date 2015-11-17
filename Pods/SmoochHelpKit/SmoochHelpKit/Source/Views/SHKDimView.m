//
//  SHKDimView.m
//  Smooch
//
//  Created by Mike on 2014-05-06.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKDimView.h"

@implementation SHKDimView

- (id)initWithTarget:(id)target action:(SEL)selector
{
    self = [super initWithFrame:CGRectZero];
    if(self){
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        
        UITapGestureRecognizer* tapDim = [[UITapGestureRecognizer alloc] initWithTarget:target action:selector];
        tapDim.numberOfTouchesRequired = 1;
        [self addGestureRecognizer:tapDim];
        
        UIPanGestureRecognizer* panDim = [[UIPanGestureRecognizer alloc] initWithTarget:target action:selector];
        panDim.maximumNumberOfTouches = 1;
        panDim.minimumNumberOfTouches = 1;
        [self addGestureRecognizer:panDim];
    }
    return self;
}

-(void)dim
{
    self.userInteractionEnabled = YES;
    [UIView animateWithDuration:0.3
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];
                     } completion:nil];
}

-(void)undim
{
    self.userInteractionEnabled = NO;
    [UIView animateWithDuration:0.3
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         self.backgroundColor = [UIColor clearColor];
                     } completion:nil];
}

@end
