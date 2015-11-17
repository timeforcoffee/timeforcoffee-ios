//
//  SHKUtility.h
//  Smooch
//
//  Created by Michael Spensieri on 12/4/13.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

BOOL SHKIsIOS8OrLater();
CGSize SHKAbsoluteScreenSize();
CGSize SHKOrientedScreenSize();

BOOL SHKIsValidZendeskUrl(NSString* url);
BOOL SHKIsTallScreenDevice();
BOOL SHKIsIpad();
BOOL SHKIsLayoutPhoneInLandscape();
NSString* SHKAddIsMobileQueryParameter(NSString* string);
CGFloat SHKNavBarHeight();
BOOL SHKIsNetworkAvailable();
UIImage* SHKTakeScreenshotOfRootWindow();
UIViewController* SHKGetTopMostViewControllerOfRootWindow();
NSString* SHKGetAppDisplayName();
CGFloat SHKGetSaturationOfColor(UIColor* color);
BOOL SHKIsStatusBarTall();
void SHKEnsureMainThread(void (^block)(void));

UIImage* SHKFancyCharacterAsImageWithColor(NSString* character, CGFloat fontSize, UIColor* fontColor);
UIImage* SHKFancyCharacterAsImage(NSString* character, CGFloat fontSize);


////  Represents the chat bubble graphic in our fancy font
static NSString* const SHKChatBubbleCharacter = @"";
