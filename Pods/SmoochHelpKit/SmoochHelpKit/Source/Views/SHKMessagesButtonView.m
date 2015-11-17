//
//  SHKMessagesButtonView.m
//  Smooch
//
//  Created by Jean-Philippe Joyal on 11/14/13.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKMessagesButtonView.h"
#import "SHKLocalization.h"
#import "SHKRoundedButton.h"
#import "SHKUtility.h"
#import "SHKStateMachine.h"
#import "SHKDropShadowView.h"
#import "SHKM13BadgeView.h"
#import <Smooch/Smooch.h>

static const int buttonHeight = 36;
static const int buttonPaddingFromBottom = 8;

@interface SHKMessagesButtonView ()

@property UIButton* button;
@property SHKDropShadowView* dropShadow;
@property SHKM13BadgeView* badge;

@end

@implementation SHKMessagesButtonView

+(CGFloat)getHeightNeededForButton
{
    return buttonHeight + (2 * buttonPaddingFromBottom);
}

+(CGFloat)getButtonMinYCoordinate
{
    return [self getHeightNeededForButton] == 0 ?: [self getHeightNeededForButton] - buttonPaddingFromBottom;
}

-(instancetype)initWithTarget:(id)target action:(SEL)action
{
    self = [super init];
    if(self){
        self.button = [SHKRoundedButton new];
        [self.button setTitle:[SHKLocalization localizedStringForKey:@"Messages"] forState:UIControlStateNormal];
        
        UIImage* chatBubbleImage = SHKFancyCharacterAsImage(SHKChatBubbleCharacter, 20);
        [self.button setImage:chatBubbleImage forState:UIControlStateNormal];
        self.dropShadow = [[SHKDropShadowView alloc] initWithFrame:self.bounds];
        
        [self addSubview:self.dropShadow];
        [self addSubview:self.button];
        [self.button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
        
        self.badge = [[SHKM13BadgeView alloc] init];
        self.badge.horizontalAlignment = SHKM13BadgeViewHorizontalAlignmentRight;
        self.badge.verticalAlignment = SHKM13BadgeViewVerticalAlignmentTop;
        self.badge.hidesWhenZero = YES;
        self.badge.alignmentShift = CGSizeMake(-5, 5);
        self.badge.font = [UIFont systemFontOfSize:13];
        [self updateBadge:[Smooch conversation]];
        [self addSubview:self.badge];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(conversationUnreadCountDidChange:) name:SKTConversationUnreadCountDidChangeNotification object:nil];
    }
    return self;
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)reframe:(CGFloat)keyboardHeight
{
    CGFloat buttonOffset = 0;
    if([SHKStateMachine currentState] == SmoochStateActive){
        buttonOffset = keyboardHeight;
    }else{
        buttonOffset = -100 * (1 - MIN(1, [SHKStateMachine currentPercentage]));
    }
    
    self.button.frame = CGRectMake(0, self.superview.bounds.size.height - buttonHeight - buttonPaddingFromBottom - buttonOffset, 0, buttonHeight);
    [self.button sizeToFit];
    self.button.center = CGPointMake(CGRectGetMidX(self.superview.bounds), self.button.center.y);
    
    // resize view to only cover button & adjust button for this new frame
    self.frame = self.button.frame;
    self.button.frame = CGRectMake(0, 0, self.button.frame.size.width, buttonHeight);
    [self.dropShadow reframe:self.button.frame];
    
    [self.badge autoSetBadgeFrame];
}

-(void)reframeAnimated:(BOOL)animated withOrientation:(UIInterfaceOrientation)orientation
{
    CGFloat keyboardHeight = [self getKeyboardHeightWithOrientation:orientation];
    
    if(keyboardHeight > 0){
        if([self.positioningDelegate respondsToSelector:@selector(messagesButtonView:shouldMoveAboveKeyboardWithHeight:orientation:)]){
            BOOL shouldMove = [self.positioningDelegate messagesButtonView:self shouldMoveAboveKeyboardWithHeight:keyboardHeight orientation:orientation];
            
            if(!shouldMove){
                keyboardHeight = 0;
            }
        }
    }
    
    if(animated){
        [self animateReframe:keyboardHeight];
    }else{
        [self reframe:keyboardHeight];
    }
}

-(void)conversationUnreadCountDidChange:(NSNotification*)notification
{
    SKTConversation* conversation = notification.object;
    [self updateBadge:conversation];
}

-(void)updateBadge:(SKTConversation*)conversation
{
    NSUInteger unreadCount = conversation.unreadCount;
    
    self.badge.text = [NSString stringWithFormat:@"%ld", (unsigned long)unreadCount];
}

@end
