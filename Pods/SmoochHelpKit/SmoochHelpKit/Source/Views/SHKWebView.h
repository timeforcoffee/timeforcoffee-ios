//
//  SHKWebView.h
//  Smooch
//
//  Created by Michael Spensieri on 11/19/13.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
@class SHKNoNetworkView;

@interface SHKWebView : UIWebView<UIWebViewDelegate>

-(void)loadURLString:(NSString*)urlString;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *cssToInject;

-(void)removeHeaderAndApplyStyling;

@property BOOL continueInjecting;
@property SHKNoNetworkView* noNetworkView;

@end
