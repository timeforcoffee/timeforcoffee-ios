//
//  SHKWebView.m
//  Smooch
//
//  Created by Michael Spensieri on 11/19/13.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKWebView.h"
#import "SHKUtility.h"
#import "SHKNoNetworkView.h"
#import "SHKLocalization.h"
#import "SmoochHelpKit.h"

static const int kSHKErrorViewPadding = 100;

@interface SHKWebView ()

@property NSURLRequest* initialRequest;
@property UIAlertView* alertView;
@property UIActivityIndicatorView* activityIndicator;

@end

@implementation SHKWebView

-(id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self){
        [self initializator];
    }
    return self;
}

-(void)initializator
{
    self.delegate = self;
    self.backgroundColor = [UIColor whiteColor];
    self.opaque = NO;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    
    [self initActivityIndicator];
    [self initNoInternetView];
}

-(void)initActivityIndicator
{
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [self addSubview:self.activityIndicator];
}

-(void)initNoInternetView
{
    self.noNetworkView = [[SHKNoNetworkView alloc] initWithFrame:CGRectMake(0, 0, SHKAbsoluteScreenSize().width - kSHKErrorViewPadding, SHKAbsoluteScreenSize().height) target:self action:@selector(refreshPage)];
    self.noNetworkView.hidden = YES;
    [self.noNetworkView sizeToFit];
    
    [self addSubview:self.noNetworkView];
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    // Position the indicator in the middle of the screen, not the middle of the view
    self.activityIndicator.center = CGPointMake(self.center.x, self.center.y - 1.5*self.frame.origin.y);
    
    if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)){
        self.noNetworkView.center = CGPointMake(self.center.x, self.center.y - self.frame.origin.y);
    }else{
        self.noNetworkView.center = self.activityIndicator.center;
    }
    
    // Resize images / videos based on new orientation
    [self reloadCSS];
}

-(void)refreshPage
{
    if(self.request != nil)
        [self loadRequest:self.request];
    else if(SHKIsNetworkAvailable()){
        [self loadRequest:self.initialRequest];
    }
}

-(void)loadURLString:(NSString*)urlString{
    NSString* stringWithMobileQueryParam = SHKAddIsMobileQueryParameter(urlString);
    NSURL* url = [[NSURL alloc] initWithString:stringWithMobileQueryParam];
    
    self.initialRequest = [[NSURLRequest alloc] initWithURL:url];
    
    if(SHKIsNetworkAvailable()){
        [self loadRequest:self.initialRequest];
    }else{
        [self showNoNetworkView];
    }
}

-(void)showNoNetworkView
{
    self.scrollView.hidden = YES;
    self.noNetworkView.hidden = NO;
}

-(void)hideNoNetworkView
{
    self.scrollView.hidden = NO;
    self.noNetworkView.hidden = YES;
}

#pragma mark - WebView Delegate

-(void)webViewDidFinishLoad:(UIWebView *)webView
{
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	[self.activityIndicator stopAnimating];
    
    [self removeHeaderAndApplyStyling];
    self.continueInjecting = NO;
}

-(void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    self.continueInjecting = NO;
    
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	[self.activityIndicator stopAnimating];
	
	if( [error code] != NSURLErrorCancelled )
	{
        UIAlertView* av = [[UIAlertView alloc] initWithTitle:[SHKLocalization localizedStringForKey:@"Error"]
                                                    message:[error localizedDescription]
                                                   delegate:nil
                                          cancelButtonTitle:[SHKLocalization localizedStringForKey:@"Okay"]
                                          otherButtonTitles:nil];
        [av show];
	}
}

-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if(!SHKIsNetworkAvailable()){
        [self showNoNetworkView];
        return NO;
    }
    
    // Accept this location change
    return YES;
}

-(void)webViewDidStartLoad:(UIWebView *)webView
{
    [self hideNoNetworkView];
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	[self.activityIndicator startAnimating];
    
    self.continueInjecting = YES;
    [self performSelector:@selector(removeHeaderAndApplyStyling) withObject:nil afterDelay:0];
}

#pragma mark - CSS Injection

// webViewDidStartLoad is too early to inject CSS, so we need to poll until the page is ready for CSS
// Keeps going until the injection is successful or until the page load fails
-(void)removeHeaderAndApplyStyling{
    if(!self.continueInjecting){
        return;
    }
    
    if(![SmoochHelpKit settings].enableZendeskArticleRestyling){
        self.continueInjecting = NO;
        return;
    }

    NSString* res = [self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"\
    if(!document.getElementById('SmoochStylingOnTopOfZendesk') && document.getElementsByTagName('header')[0]){\
        document.getElementsByTagName('header')[0].style.display = 'none';\
        %@\
    }\
    var elems = document.getElementsByClassName('comments-title');\
    for(var i=0; i != elems.length; ++i){\
        if(/\\(0\\)/.test(elems[i].innerHTML) ){\
            elems[i].style.display = 'none';\
            'stop';\
        }\
    }\
    ", [self cssInjectionString]]];
    
    if([res isEqualToString:@"stop"]){
        self.continueInjecting = NO;
    }else{
        [self performSelector:@selector(removeHeaderAndApplyStyling) withObject:nil afterDelay:0];
    }
}

-(NSString*) cssInjectionString
{
    return [NSString stringWithFormat:@"\
            document.getElementsByTagName('head')[0].innerHTML +=\
            '<style id=\"SmoochStylingOnTopOfZendesk\">%@</style>';", [self cssToInject]];
}

-(NSString*) cssToInject{
    // Multiply by 0.88 to allow some padding on the sides
    int elementMaxWidth = self.bounds.size.width * 0.88;
    
    return [NSString stringWithFormat:@"\
        body{\
            background-color:white;\
            background-image:none;\
        }\
        body a{\
            word-break:break-all;\
        }\
        .sub-header{\
            display:none;\
        }\
        img,iframe{\
            max-width:%dpx;\
            height:auto;\
        }\
        .footer, #sign-out-fullsite, .page-title{\
            display:none;\
        }\
        div.wrapper{\
            border-bottom: hidden;\
            webkit-box-shadow:none;\
            box-shadow:none;\
        }\
    ",elementMaxWidth];
}

-(void)reloadCSS
{
    if(![SmoochHelpKit settings].enableZendeskArticleRestyling){
        return;
    }
    
    [self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"\
    var css = document.getElementById('SmoochStylingOnTopOfZendesk');\
    css.parentNode.removeChild(css);\
    %@" , [self cssInjectionString]]];
}

-(void)dealloc
{
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

@end
