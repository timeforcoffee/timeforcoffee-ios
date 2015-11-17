//
//  SHKWindow.m
//  Smooch
//
//  Created by Michael Spensieri on 2/24/14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKWindow.h"
#import "SHKNavigationViewController.h"
#import "SHKStateMachine.h"
#import "SHKTransition.h"

NSString* const SmoochWindowResizingNotification = @"SmoochWindowResizingNotification";

@implementation SHKWindow

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        
        // Initialization code
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillChangeStatusBarHeight) name:UIApplicationWillChangeStatusBarFrameNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidChangeStatusBarHeight) name:UIApplicationDidChangeStatusBarFrameNotification object:nil];
        
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBeginTransition:) name:SHKStateMachineDidEnterTransitioningStateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive) name:SHKStateMachineDidEnterActiveStateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeSemiActive) name:SHKStateMachineDidEnterSemiActiveStateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeInactive) name:SHKStateMachineDidEnterInactiveStateNotification object:nil];
        
    }
    return self;
}

-(void)didBeginTransition:(NSNotification*)notification
{
    if(self.hidden){
        self.hidden = NO;
    }
    
    [self smoochDidBeginTransition:notification.object];
}

-(void)didBecomeActive
{
    if(self.hidden){
        self.hidden = NO;
    }
    [self smoochDidBecomeActive];
}

-(void)didBecomeSemiActive
{
    if(self.hidden){
        self.hidden = NO;
    }
    [self smoochDidBecomeSemiActive];
}

-(void)didBecomeInactive
{
    if(!self.hidden){
        self.hidden = YES;
    }
    [self smoochDidBecomeInactive];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// Override if you want to act on these notifications
-(void)smoochDidBeginTransition:(SHKTransition *)transition {}
-(void)smoochDidBecomeActive {}
-(void)smoochDidBecomeSemiActive {}
-(void)smoochDidBecomeInactive {}

-(void)appWillChangeStatusBarHeight {}
-(void)appDidChangeStatusBarHeight {}


@end
