//
//  SHKOffsetManager.h
//  Smooch
//
//  Created by Mike on 2014-05-15.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString* const SHKOffsetManagerDidChangePercentageNotification;

extern const CGFloat SHKOffsetManagerInactivePercentage;
extern const CGFloat SHKOffsetManagerActivePercentage;
extern const CGFloat SHKOffsetManagerSemiActivePercentage;
extern const CGFloat SHKOffsetManagerMiniaturePercentage;

@interface SHKOffsetManager : NSObject

@property CGFloat activeStateSnapPercentage;
@property CGFloat offsetPercentage;
@property(readonly) CGFloat bouncePercentage;

@property (NS_NONATOMIC_IOSONLY, readonly) BOOL shouldBounce;
-(void)animateToPercentage:(CGFloat)percentage isDragging:(BOOL)isDragging withCompletion:(void (^)(void))completion;

@end
