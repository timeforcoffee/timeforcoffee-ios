//
//  SHKOverlayWindow.h
//  Smooch
//
//  Created by Michael Spensieri on 1/27/14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SHKWindow.h"
@class SHKSettings;

@interface SHKOverlayWindow : SHKWindow

-(instancetype)initWithFrame:(CGRect)frame settings:(SHKSettings*)settings;

-(void)attachGestureRecognizers;
-(BOOL)endEditing;

+(CGFloat)getMaxScaleDownFactor;

-(void)startWatchingForFrameChangesOnMainWindow;
-(void)stopWatchingForFrameChangesOnMainWindow;

@end
