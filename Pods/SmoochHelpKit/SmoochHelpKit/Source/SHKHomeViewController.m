//
//  SHKHomeViewController.m
//  Smooch
//
//  Created by Michael Spensieri on 11/12/13.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKHomeViewController.h"
#import "SHKLocalization.h"
#import "SmoochHelpKit+Private.h"
#import "SHKUtility.h"
#import "SHKSearchBarView.h"
#import "SHKNavigationViewController.h"
#import "SHKSearchResultsView.h"
#import "SHKSearchResult.h"
#import "SHKRecommendationsViewController.h"
#import "SHKDimView.h"
#import "SHKSearchController.h"
#import "SHKTableCellVendingMachine.h"
#import "SHKRecommendations.h"
#import "SHKAlphaGradientLayer.h"

static const int kSearchBarPortraitHorizontalStretch = 12;

NSString* const SHKSearchBarTextDidBeginEditing = @"SHKSearchBarTextDidBeginEditing";

@interface SHKHomeViewController ()

@property SHKSearchResultsView* searchResultsView;
@property BOOL firstLaunch;
@property SHKDimView* dimView;
@property SHKRecommendationsViewController* recommendationsViewController;
@property SHKSearchController* searchController;
@property NSTimer* typingFinishedTimer;
@property SHKTableCellVendingMachine* vendingMachine;
@property SHKAlphaGradientLayer *ghostLayer;

@end

@implementation SHKHomeViewController

-(instancetype)initWithSearchController:(SHKSearchController*)searchController
{
    self = [super init];
    if(self){
        _firstLaunch = YES;
        _vendingMachine = [SHKTableCellVendingMachine new];
        _searchController = searchController;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardShown:) name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(searchResultsChanged) name:SHKSearchControllerResultsDidChangeNotification object:nil];
    }
    return self;
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self cancelTypingTimer];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self initCloseButton];
    [self initRecommendationsController];
    [self initDimView];
    [self initSearchResultsView];
    
    self.searchBar.frame = CGRectMake(self.searchBar.frame.origin.x - kSearchBarPortraitHorizontalStretch/2,
                                      self.searchBar.frame.origin.y,
                                      self.searchBar.frame.size.width + kSearchBarPortraitHorizontalStretch,
                                      self.searchBar.frame.size.height);
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self setMessagesButtonPositioningDelegate:self];
    
    if(!animated)
    {
        if(self.firstLaunch){
            self.firstLaunch = NO;
        }else{
            [self.searchBar becomeFirstResponder];
        }
    }
    
    [self.searchResultsView.tableView deselectRowAtIndexPath:self.searchResultsView.tableView.indexPathForSelectedRow animated:YES];
}

-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    self.dimView.frame = self.view.bounds;
    self.searchResultsView.frame = self.view.bounds;
    [self reframeGhostLayer];
}

-(void)reframeGhostLayer
{
    self.ghostLayer.transform = CATransform3DIdentity;
    self.ghostLayer.frame = [UIApplication sharedApplication].delegate.window.bounds;
    [self.ghostLayer setGradientPoints];
}

- (void)initGhostLayer
{
    self.ghostLayer = [[SHKAlphaGradientLayer alloc] init];
    [self reframeGhostLayer];
    [[UIApplication sharedApplication].delegate.window.layer setMask:self.ghostLayer];
}

- (void)removeGhostLayer
{
    [[UIApplication sharedApplication].delegate.window.layer setMask:nil];
    self.ghostLayer = nil;
}

-(void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    [self.ghostLayer setGradientPointsForOrientation:toInterfaceOrientation];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self onViewHidden];
}

-(void)onSmoochBecameActive
{
    [self setMessagesButtonPositioningDelegate:self];
    
    if([self.recommendationsViewController.recommendationsManager numberOfRecommendationsInSwipeView] == 0 && self.searchBar.text.length == 0){
        [self.searchBar becomeFirstResponder];
    }
}

-(void)onSmoochBecameInactive
{
    [self onViewHidden];
}

-(void)onViewHidden
{
    [self.searchBar resignFirstResponder];
    
    [self setMessagesButtonPositioningDelegate:nil];
    
    [self setUserFinishedTyping];
}

-(void)setMessagesButtonPositioningDelegate:(id<SHKMessagesButtonPositioningDelegate>)delegate
{
    SHKNavigationViewController* navigationController = (SHKNavigationViewController*)self.navigationController;
    navigationController.messagesButton.positioningDelegate = delegate;
}

-(void)initRecommendationsController
{
    self.recommendationsViewController = [[SHKRecommendationsViewController alloc] init];
    [self addChildViewController:self.recommendationsViewController];
    [self.view addSubview:self.recommendationsViewController.view];
}

-(void)initSearchResultsView
{
    self.searchResultsView = [[SHKSearchResultsView alloc] init];
    self.searchResultsView.tableView.delegate = self;
    self.searchResultsView.tableView.dataSource = self;
    
    [self.view addSubview:self.searchResultsView];
}

-(void)initCloseButton
{
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[SHKLocalization localizedStringForKey:@"Close"]
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(onClose)];
}

-(void)initCancelButton
{
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[SHKLocalization localizedStringForKey:@"Cancel"]
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(onCancel)];
}

-(void)initDimView
{
    self.dimView = [[SHKDimView alloc] initWithTarget:self.searchBar action:@selector(resignFirstResponder)];
    
    [self.view addSubview:self.dimView];
}

-(void)onClose
{
    [self endEditing];
    
    [SmoochHelpKit close];
}

-(void)onCancel
{
    [self.searchBar resignFirstResponder];
    [self.searchController cancelCurrentRequest];
    self.searchResultsView.hidden = YES;
    
    [self toggleNavigationItems];
}

-(void)toggleNavigationItems
{
    if([self.searchBar isFirstResponder] || !self.searchResultsView.hidden){
        if(self.navigationItem.rightBarButtonItem == nil){
            [self removeLeftAndAddRight];
        }
    }else{
        if(self.navigationItem.leftBarButtonItem == nil){
            [self removeRightAndAddLeft];
        }
    }
}

-(void)removeLeftAndAddRight
{
    [UIView animateWithDuration:0.2
                     animations:^{
                         self.navigationItem.leftBarButtonItem = nil;
                     }];
    [self initCancelButton];
}

-(void)removeRightAndAddLeft
{
    [UIView animateWithDuration:0.2
                     animations:^{
                         self.navigationItem.rightBarButtonItem = nil;
                     }];
    [self initCloseButton];
}

-(void)endEditing
{
    [self.searchBar resignFirstResponder];
    
    [self.recommendationsViewController resetSwipeViewToStart];
}

-(void)showBadUrlError
{
    NSString* errorMessage = [SHKLocalization localizedStringForKey:SHKBadKnowledgeBaseUrlErrorText];
    NSLog(@"%@", errorMessage);
    
    self.searchController.error = [NSError errorWithDomain:@"Smooch" code:SHKBadKnowledgeBaseUrlErrorCode
                                                  userInfo:@{ NSLocalizedDescriptionKey:errorMessage }];
    
    [self searchResultsChanged];
    self.searchResultsView.hidden = NO;
}

-(void)searchResultsChanged
{
    self.searchResultsView.hidden = self.searchBar.text.length == 0;
    
    [self.searchResultsView.tableView reloadData];
    
    SHKNavigationViewController* navigationController = (SHKNavigationViewController*)self.navigationController;
    [navigationController.messagesButton reframeAnimated:YES];
}

-(void)scheduleTwoSecondTypingTimer
{
    [self cancelTypingTimer];
    self.typingFinishedTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(setUserFinishedTyping) userInfo:nil repeats:NO];
}

-(void)setUserFinishedTyping
{
    @synchronized(self){
        [self cancelTypingTimer];
    }
}

-(void)cancelTypingTimer
{
    @synchronized(self) {
        if (self.typingFinishedTimer != nil) {
            [self.typingFinishedTimer invalidate];
            self.typingFinishedTimer = nil;
        }
    }
}

-(void)keyboardShown:(NSNotification*)notification
{
    // Background is only dimmed when the search bar is pressed - prevents shadow from appearing on chat window
    if (self.dimView.backgroundColor != [UIColor clearColor] &&
        [[SmoochHelpKit getRecommendations].recommendationsList count] <= 0) {
        [self initGhostLayer];
    }
}

#pragma mark - UISearchBarDelegate

-(void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self.searchController search:searchText];
    
    // If the user has not typed in 2 seconds, log a search event
    [self scheduleTwoSecondTypingTimer];
}

-(BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar
{
    [self.dimView dim];
    
    self.searchResultsView.hidden = self.searchBar.text.length == 0;
    return YES;
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SHKSearchBarTextDidBeginEditing object:nil];
    
    [self toggleNavigationItems];
}

-(void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    [self.dimView undim];
    [self removeGhostLayer];
    [self toggleNavigationItems];
}

#pragma mark - UITableViewDelegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self setUserFinishedTyping];
    [self.searchBar resignFirstResponder];
    
    SHKSearchResult* searchResult = [self.searchController searchResultAtIndex:indexPath.row];
    
    SHKNavigationViewController* navController = (SHKNavigationViewController*)self.navigationController;
    [navController showArticle:searchResult.htmlURL];
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat maxWidth = self.searchResultsView.frame.size.width;
    
    if(self.searchController.error != nil){
        return [self.vendingMachine heightForError:self.searchController.error constrainedToWidth:maxWidth];
    }
    
    return [self.vendingMachine heightForSearchResult:[self.searchController searchResultAtIndex:indexPath.row] constrainedToWidth:maxWidth];
}

-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [self.searchBar resignFirstResponder];
    
    [self setUserFinishedTyping];
}

#pragma mark - UITableViewDataSource

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(self.searchController.error != nil){
        return [self.vendingMachine cellForError:self.searchController.error dequeueFrom:tableView];
    }
    
    return [self.vendingMachine cellForSearchResult:[self.searchController searchResultAtIndex:indexPath.row] dequeueFrom:tableView];
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.searchController.error) {
        return 1;
    }
    
    return MAX(1, self.searchController.searchResults.count);
}

#pragma mark - SHKMessagesButtonPositioningDelegate

-(BOOL)messagesButtonView:(SHKMessagesButtonView *)messagesButton shouldMoveAboveKeyboardWithHeight:(CGFloat)keyboardHeight orientation:(UIInterfaceOrientation)orientation
{
    // Cannot use self.view.bounds height because it doesn't handle orientation the way we want
    CGSize screenSize = SHKAbsoluteScreenSize();
    CGFloat viewHeight = screenSize.height;
    
    if(UIInterfaceOrientationIsLandscape(orientation)) {
        viewHeight = screenSize.width;
    }
    
    CGFloat availableSpace = viewHeight - SHKNavBarHeight() - self.searchResultsView.tableView.contentSize.height - keyboardHeight;
    
    BOOL hasSpace = availableSpace >= [SHKMessagesButtonView getHeightNeededForButton];
    BOOL hasRecommendations = [[SmoochHelpKit getRecommendations].recommendationsList count] > 0;
    BOOL tableViewShown = !self.searchResultsView.hidden;
    
    if((!tableViewShown && !hasRecommendations) || (tableViewShown && hasSpace)){
        return YES;
    }else{
        return NO;
    }
}

@end
