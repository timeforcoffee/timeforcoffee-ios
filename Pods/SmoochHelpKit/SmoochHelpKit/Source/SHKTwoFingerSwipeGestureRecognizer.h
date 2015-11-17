//
//  SHKTwoFingerSwipeGestureRecognizer.h
//  Smooch
//
//  Created by Michael Spensieri on 2/18/14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SHKTwoFingerSwipeGestureRecognizer : UIPanGestureRecognizer

@property (nonatomic, readonly) CGFloat verticalOffset;
@property (nonatomic, readonly) CGFloat verticalVelocity;

@end
