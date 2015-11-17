//
//  SHKRecommendationPreviewView.h
//  Smooch
//
//  Created by Michael Spensieri on 4/16/14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
@class SHKVerticalProgressView;

@interface SHKRecommendationPreviewView : UIImageView

-(void)crossfadeToImage:(UIImage *)image;
-(void)markAsFailed;

@property SHKVerticalProgressView* loadingBar;

@end
