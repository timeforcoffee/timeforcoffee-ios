//
//  SHKUnderlayViewController.h
//  Smooch
//
//  Created by Michael Spensieri on 2/11/14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SHKGradientView.h"
#import "SHKDropShadowView.h"

@interface SHKUnderlayViewController : UIViewController

-(void)lighten;
-(void)darkenWithAlpha:(CGFloat)alpha;

@property SHKGradientView* gradientView;
@property SHKDropShadowView* dropShadowViewForWindow;

@end
