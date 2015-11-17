//
//  SHKArticleScreenshotWebView.m
//  Smooch
//
//  Created by Michael Spensieri on 4/11/14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKArticleScreenshotWebView.h"
#import "SHKUtility.h"

@interface SHKArticleScreenshotWebView()

@property(copy) SHKImageLoaderCompletionBlock completion;
@property NSTimer* timeoutTimer;

// Used to keep track of didStartLoad, didFinishLoad, and didFailWithError counts
@property int loadCount;

@end

@implementation SHKArticleScreenshotWebView

-(id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self){
        self.loadCount = 0;
    }
    return self;
}

-(void)loadImageForUrl:(NSString *)urlString withCompletion:(SHKImageLoaderCompletionBlock)completion
{
    [self forceClearWebViewContents];
    
    self.completion = completion;
    self.loadCount = 0;
    
    NSString* stringWithMobileQueryParam = SHKAddIsMobileQueryParameter(urlString);
    NSURL* url = [[NSURL alloc] initWithString:stringWithMobileQueryParam];
    
    [self loadRequest:[[NSURLRequest alloc] initWithURL:url]];
    
    self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:15 target:self selector:@selector(timeout) userInfo:nil repeats:NO];
}

-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    // Do not forward to super
    
    return YES;
}

-(void)webViewDidStartLoad:(UIWebView *)webView
{
    [super webViewDidStartLoad:webView];
    
    self.loadCount++;
}

-(void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    // Do not forward to super
    
    if(error.code == NSURLErrorCancelled){
        return;
    }
    
    self.loadCount--;
    
    if(self.loadCount == 0){
        [self.timeoutTimer invalidate];
        self.continueInjecting = NO;
        [self stopLoading];
        [self completeRequestWithImage:nil];
    }
}

-(void)webViewDidFinishLoad:(UIWebView *)webView
{
    [super webViewDidFinishLoad:webView];
    
    self.loadCount--;
    
    if(self.loadCount == 0){
        [self.timeoutTimer invalidate];
        [self stopLoading];
        [self takeScreenshot];
    }
}

-(void)takeScreenshot
{
    UIGraphicsBeginImageContext(self.bounds.size);
    
    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    
    UIImage* img = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    [self completeRequestWithImage:img];
}

-(void)forceClearWebViewContents
{
    // The holy grail of bug fixes : Solves the issue of the webview taking a screenshot of the wrong page
    [self stringByEvaluatingJavaScriptFromString:@"document.open();document.close();"];
}

-(void)timeout
{
    self.continueInjecting = NO;
    [self stopLoading];
    [self completeRequestWithImage:nil];
}

-(void)completeRequestWithImage:(UIImage*)image
{
    [self forceClearWebViewContents];
    
    if(self.completion){
        self.completion(image);
    }
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
