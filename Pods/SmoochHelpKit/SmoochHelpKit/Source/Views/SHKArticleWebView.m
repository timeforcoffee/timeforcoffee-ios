//
//  SHKArticleWebView.m
//  Smooch
//
//  Created by Jean-Philippe Joyal on 11/22/13.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKArticleWebView.h"
#import "SHKMessagesButtonView.h"
#import "SHKNoNetworkView.h"
#import "SHKUtility.h"

static const int kNoNetworkViewTopPadding = 5;

@implementation SHKArticleWebView

-(id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self){
        [self appendPlacehoderForMessagesButton];
    }
    return self;
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    // Make sure the no network view does not overlap the messages button
    if (SHKIsLayoutPhoneInLandscape() && [SHKMessagesButtonView getHeightNeededForButton] > 0){
        CGRect frame = self.noNetworkView.frame;
        frame.origin.y = kNoNetworkViewTopPadding;
        self.noNetworkView.frame = frame;
    }
}

-(NSString*) cssToInject{
    NSString* css = [super cssToInject];
    return [css stringByAppendingString:@"\
            .button{\
                display:none !important;\
                padding:0;\
            }\
            .comments-title,.comments-wrapper{\
                display:block;\
            }\
            .comments-title + p {\
                display:none;\
            }\
    "];
}

-(void)appendPlacehoderForMessagesButton{
    [self.scrollView setContentInset:UIEdgeInsetsMake(0,0, [SHKMessagesButtonView getHeightNeededForButton], 0)];
}

@end
