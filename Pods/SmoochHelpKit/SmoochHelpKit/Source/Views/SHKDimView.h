//
//  SHKDimView.h
//  Smooch
//
//  Created by Mike on 2014-05-06.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SHKDimView : UIView

-(instancetype)initWithTarget:(id)target action:(SEL)selector;

-(void)dim;
-(void)undim;

@end
