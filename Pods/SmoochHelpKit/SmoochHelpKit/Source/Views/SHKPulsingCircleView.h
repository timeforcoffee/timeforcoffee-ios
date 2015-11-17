//
//  SHKCircleView.h
//  Smooch
//
//  Created by Jean-Philippe Joyal on 5/8/14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
@class SHKPulsingCircleContainerView;

@interface SHKPulsingCircleView : UIView
+ (CAShapeLayer*) circleShapeWithRadius:(int)radius withFrame:(CGRect)frame;
-(id)initWithFrame:(CGRect)frame withContainer:(SHKPulsingCircleContainerView*)container;
- (void) animate;
@end
