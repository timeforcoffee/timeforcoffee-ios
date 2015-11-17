//
//  SHKAlphaGradientLayer.h
//  Smooch
//
//  Created by Joel Simpson on 2014-08-28.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SHKAlphaGradientLayer : CAGradientLayer

-(void)setGradientPoints;
-(void)setGradientPointsForOrientation:(UIInterfaceOrientation)orientation;

@end
