//
//  SHKArticleViewController.m
//  Smooch
//
//  Created by Michael Spensieri on 11/25/13.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKArticleViewController.h"
#import "SHKArticleWebView.h"
#import "SHKSearchBarView.h"
#import "SHKNavigationViewController.h"
#import "SHKUtility.h"
#import "SmoochHelpKit+Private.h"
#import "SHKOverlayWindow.h"

@interface SHKArticleViewController ()

@property SHKArticleWebView* webView;

@property NSString* rootUrlString;

@end

@implementation SHKArticleViewController

-(id)initWithUrlString:(NSString*)urlString
{
    self = [super init];
    if(self){
        self.rootUrlString = urlString;
    }
    return self;
}

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    [self initWebView];
    
    self.edgesForExtendedLayout = UIRectEdgeNone;
    [self.webView loadURLString:self.rootUrlString];
    
    if(self.showsSearchBar){
        [self.searchBar setImage:[UIImage new] forSearchBarIcon:UISearchBarIconClear state:UIControlStateNormal];
    }else{
        self.navigationItem.titleView.hidden = YES;
    }
}

-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    self.webView.frame = self.view.bounds;
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [[SmoochHelpKit overlayWindow] startWatchingForFrameChangesOnMainWindow];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(smoochBecameActive) name:SHKStateMachineDidEnterActiveStateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(smoochBecameInactive) name:SHKStateMachineDidEnterInactiveStateNotification object:nil];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SHKStateMachineDidEnterActiveStateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SHKStateMachineDidEnterInactiveStateNotification object:nil];
    
    if(self.isMovingFromParentViewController){
        [[SmoochHelpKit overlayWindow] stopWatchingForFrameChangesOnMainWindow];
    }
}

-(void)smoochBecameActive
{
    [[SmoochHelpKit overlayWindow] startWatchingForFrameChangesOnMainWindow];
}

-(void)smoochBecameInactive
{
    [[SmoochHelpKit overlayWindow] stopWatchingForFrameChangesOnMainWindow];
}

-(void)initWebView
{
    self.webView = [SHKArticleWebView new];
    
    [self.view addSubview:self.webView];
}

-(void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    [self.navigationController popViewControllerAnimated:NO];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[SmoochHelpKit overlayWindow] stopWatchingForFrameChangesOnMainWindow];
}

@end
