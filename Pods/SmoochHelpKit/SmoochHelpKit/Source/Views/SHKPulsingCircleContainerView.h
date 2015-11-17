//
//  SHKPulsingCircleView.h
//  Smooch
//
//  Created by Jean-Philippe Joyal on 5/7/14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SHKPulsingCircleView.h"

@interface SHKPulsingCircleContainerView : UIView

- (void) removeCircle: (SHKPulsingCircleView*) circle;
- (void)pulseXTimes:(int)times;

@end
