//
//  SHKTutorialView.h
//  Smooch
//
//  Created by Dominic Jodoin on 2/24/2014.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SHKTutorialView : UIView

@property UIButton* skipButton;

-(void)startAnimation;
-(void)cancelAnimation;

@end
