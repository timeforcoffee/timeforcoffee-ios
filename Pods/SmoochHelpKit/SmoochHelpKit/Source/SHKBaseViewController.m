//
//  SHKBaseViewController.m
//  Smooch
//
//  Created by Michael Spensieri on 11/25/13.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKBaseViewController.h"
#import "SHKLocalization.h"
#import "SHKUtility.h"
#import "SHKSearchBarView.h"
#import "SHKNavigationViewController.h"
#import "SHKStateMachine.h"

static const CGFloat kSearchBarHorizontalInsetIOS8 = 7;

@interface SHKBaseViewController ()

@property NSString* searchBarText;
@property BOOL isShown;

@end

@implementation SHKBaseViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self initSearchBar];
    
    self.automaticallyAdjustsScrollViewInsets = NO;
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Caveman-style override for button text attributes
    [self.navigationItem.leftBarButtonItem setTitleTextAttributes:nil forState:UIControlStateNormal];
    [self.navigationItem.rightBarButtonItem setTitleTextAttributes:nil forState:UIControlStateNormal];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self selector:@selector(handleSmoochBecameInactive) name:SHKStateMachineDidEnterInactiveStateNotification object:nil];
    [[NSNotificationCenter defaultCenter]
     addObserver:self selector:@selector(handleSmoochBecameActive) name:SHKStateMachineDidEnterActiveStateNotification object:nil];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SHKStateMachineDidEnterActiveStateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SHKStateMachineDidEnterInactiveStateNotification object:nil];
}

-(void)handleSmoochBecameInactive
{
    @synchronized(self){
        if(self.isShown) {
            self.isShown = NO;
            [self onSmoochBecameInactive];
        }
    }
}

-(void)handleSmoochBecameActive
{
    @synchronized(self){
        if(!self.isShown) {
            self.isShown = YES;
            [self onSmoochBecameActive];
        }
    }
}

-(void)onSmoochBecameInactive
{
    // Override to do something
}

-(void)onSmoochBecameActive
{
    // Override to do something
}

-(void)initSearchBar
{
    CGRect frame = CGRectMake(0, 0, self.view.bounds.size.width, SHKNavBarHeight());
    CGRect searchBarFrame = frame;
    if(SHKIsIOS8OrLater()){
        searchBarFrame = CGRectInset(frame, kSearchBarHorizontalInsetIOS8, 0);
    }
    
    NSString* appName = SHKGetAppDisplayName();
    

    self.searchBar = [[SHKSearchBarView alloc] initWithFrame:searchBarFrame
                                                           text:self.searchBarText
                                                 andPlaceholder:[NSString stringWithFormat:[SHKLocalization localizedStringForKey:@"Search %@ Help"], appName]];
    
    // We need this container view to stop the OS from hiding the "Back" text on the navbar back button
    UIView* container = [[UIView alloc] initWithFrame:frame];
    container.backgroundColor = [UIColor clearColor];
    [container addSubview:self.searchBar];
    container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    self.navigationItem.titleView = container;

    self.searchBar.delegate = self;
}

-(UITextField*)findTextFieldInSubviewsRecursively:(UIView*)view
{
    if([view isKindOfClass:[UITextField class]]){
        return (UITextField*)view;
    }
    
    for (UIView *subView in view.subviews){
        UITextField* field = [self findTextFieldInSubviewsRecursively:subView];
        if(field != nil){
            return field;
        }
    }
    
    return nil;
}

-(void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [self.searchBar resignFirstResponder];
}

-(void)setSearchText:(NSString *)searchText
{
    self.searchBarText = [searchText copy];
}

-(BOOL)messagesButtonView:(SHKMessagesButtonView *)messagesButton shouldMoveAboveKeyboardWithHeight:(CGFloat)keyboardHeight orientation:(UIInterfaceOrientation)orientation
{
    return NO;
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
