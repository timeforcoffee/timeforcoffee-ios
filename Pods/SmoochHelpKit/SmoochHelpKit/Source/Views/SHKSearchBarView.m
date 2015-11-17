//
//  SHKSearchBarView.m
//  Smooch
//
//  Created by Dominic Jodoin on 1/20/2014.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKSearchBarView.h"
#import "SHKUtility.h"
#import "SHKSearchController.h"

@interface SHKSearchBarView ()

@property(weak) UITextField* internalTextField;
@property UIActivityIndicatorView* spinnerView;
@property NSTimer* progressSpinnerTimer;

@end

@implementation SHKSearchBarView

-(id)initWithFrame:(CGRect)frame text:(NSString*)text andPlaceholder:(NSString*)placeholder
{
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.backgroundImage = [UIImage new];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        self.text = text;
        self.placeholder = placeholder;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startTimer) name:SHKSearchStartedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hideSpinner) name:SHKSearchCancelledNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hideSpinner) name:SHKSearchCompleteNotification object:nil];
    }
    
    return self;
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    if(!self.internalTextField){
        // in iOS 7.1, the text field is not initialized before this, so we cannot find it in -initWithFrame:
        self.internalTextField = [self findTextFieldInSubviewsRecursively:self];
        self.internalTextField.backgroundColor = [UIColor whiteColor];
    }
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

-(void)startTimer
{
    dispatch_async(dispatch_get_main_queue(), ^{
        @synchronized(self) {
            [self resetProgressSpinnerTimer];
            self.progressSpinnerTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(showSpinner) userInfo:nil repeats:NO];
        }
    });
}

- (void)resetProgressSpinnerTimer
{
    @synchronized(self) {
        if (self.progressSpinnerTimer != nil) {
            [self.progressSpinnerTimer invalidate];
            self.progressSpinnerTimer = nil;
        }
    }
}

- (void)showSpinner
{
    if(self.internalTextField)
    {
        if(self.spinnerView == nil) {
            self.spinnerView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            
            // Find search bar clear button
            UIButton* clearButton = [self findElementOfClass:[UIButton class] inSubviews:self.internalTextField.subviews];
            
            // Scale down spinner view to fit clear icon size
            CGFloat scaleFactor = clearButton.imageView.frame.size.width / self.spinnerView.frame.size.width;
            self.spinnerView.transform = CGAffineTransformMakeScale(scaleFactor, scaleFactor);
        }
        
        [self.internalTextField setClearButtonMode:UITextFieldViewModeNever];
        [self.internalTextField setRightViewMode:UITextFieldViewModeAlways];
        
        [self.internalTextField setRightView:self.spinnerView];
        
        [self.spinnerView startAnimating];
    }
}

- (void)hideSpinner
{
    [self resetProgressSpinnerTimer];
    
    [self.spinnerView stopAnimating];
    
    [self.internalTextField setRightViewMode:UITextFieldViewModeNever];
    [self.internalTextField setClearButtonMode:UITextFieldViewModeAlways];
}

- (id)findElementOfClass:(Class)class inSubviews:(NSArray*)subviews
{
    id element = nil;
    for (UIView *subview in subviews) {
        if ([subview isKindOfClass:class]) {
            element = subview;
            break;
        }
    }
    return element;
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end