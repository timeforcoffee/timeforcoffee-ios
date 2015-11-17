//
//  SHKTwoFingerSwipeGestureRecognizer.m
//  Smooch
//
//  Created by Michael Spensieri on 2/18/14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKTwoFingerSwipeGestureRecognizer.h"
#import <UIKit/UIGestureRecognizerSubclass.h>
#import "SHKUtility.h"

static const CGFloat kMinimumDistanceRequiredPerFinger = 0.5;
static const CGFloat kMinimumDistanceRequiredBeforeGestureStarts = 25;
static const CGFloat kMaximumDistanceBetweenFinger = 225;

@interface  SHKTwoFingerSwipeGestureRecognizer()

@property UITouch* firstTouch;
@property UITouch* secondTouch;
@property CGFloat originalLocationOfFirstTouch;
@property CGFloat originalLocationOfSecondTouch;

@end

@implementation SHKTwoFingerSwipeGestureRecognizer

-(id)initWithTarget:(id)target action:(SEL)action
{
    self = [super initWithTarget:target action:action];
    if(self){
        self.minimumNumberOfTouches = 2;
        self.maximumNumberOfTouches = 2;
    }
    return self;
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(touches.count == 2){
        BOOL movingUp = YES;
        BOOL movingDown = YES;
        
        // Make sure both touches are moving in the same direction
        for(UITouch* t in touches){
            CGFloat movement = [self movementOfTouch:t];
            movingUp = movingUp && (movement <= -kMinimumDistanceRequiredPerFinger);
            movingDown = movingDown && (movement >= kMinimumDistanceRequiredPerFinger);
        }
        
        if(movingUp || movingDown){
            if(self.state == UIGestureRecognizerStatePossible){
                BOOL start = YES;
                
                for(UITouch* t in touches){
                    start &= ABS([self totalMovementOfTouch:t]) > kMinimumDistanceRequiredBeforeGestureStarts;
                }
                
                if(start){
                    self.state = UIGestureRecognizerStateBegan;
                    [super touchesMoved:touches withEvent:event];
                    [self setTranslation:CGPointZero inView:self.view];
                }
            }
            
            [super touchesMoved:touches withEvent:event];
        }
    }
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    // if a third touch comes in after when first began, cancel the whole gesture
    if(touches.count > 2 ||
       (self.firstTouch != nil && self.secondTouch != nil)){
        self.state = UIGestureRecognizerStateFailed;
    }
    
    for(UITouch* t in touches){
        if(self.firstTouch == nil){
            self.firstTouch = t;
            self.originalLocationOfFirstTouch = [self getYComponentOfPoint:[t locationInView:self.view]];
        }else{
            self.secondTouch = t;
            self.originalLocationOfSecondTouch = [self getYComponentOfPoint:[t locationInView:self.view]];
        }
    }
    
    if(self.firstTouch != nil && self.secondTouch != nil){
        if([self distanceBetweenTouches] > kMaximumDistanceBetweenFinger){
            self.state = UIGestureRecognizerStateFailed;
        }
    }
    
    [super touchesBegan:touches withEvent:event];
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(self.state == UIGestureRecognizerStateChanged){
        self.state = UIGestureRecognizerStateEnded;
    }
    [super touchesEnded:touches withEvent:event];
}

-(void)reset
{
    [super reset];
    
    self.firstTouch = nil;
    self.originalLocationOfFirstTouch = NAN;
    
    self.secondTouch = nil;
    self.originalLocationOfSecondTouch = NAN;
}

-(CGFloat)totalMovementOfTouch:(UITouch*)touch
{
    if(touch == self.firstTouch){
        return [self getYComponentOfPoint:[self.firstTouch locationInView:self.view]] - self.originalLocationOfFirstTouch;
    }else if(touch == self.secondTouch){
        return [self getYComponentOfPoint:[self.secondTouch locationInView:self.view]] - self.originalLocationOfSecondTouch;
    }
    
    return NAN;
}
-(CGFloat)distanceBetweenTouches
{
    CGFloat yDistance = [self.firstTouch locationInView:self.view].y - [self.secondTouch locationInView:self.view].y;
    CGFloat xDistance = [self.firstTouch locationInView:self.view].x - [self.secondTouch locationInView:self.view].x;
    
    return sqrt((yDistance * yDistance) + (xDistance * xDistance));
}

-(CGFloat)movementOfTouch:(UITouch*)touch
{
    CGFloat touchY = [self getYComponentOfPoint:[touch locationInView:self.view]];
    CGFloat previousTouchY = [self getYComponentOfPoint:[touch previousLocationInView:self.view]];
    
    return touchY - previousTouchY;
}

-(CGFloat)verticalOffset
{
    CGPoint translatedPoint = [self translationInView:self.view];
    
    return [self getYComponentOfPoint:translatedPoint];
}

-(CGFloat)verticalVelocity
{
    CGPoint velocity = [self velocityInView:self.view];
    
    return [self getYComponentOfPoint:velocity];
}

-(CGFloat)getYComponentOfPoint:(CGPoint)point
{
    CGFloat offset = point.y;
    
    if(SHKIsIOS8OrLater()){
        return offset;
    }
    
    // Take screen orientation into account
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    if(orientation == UIInterfaceOrientationLandscapeLeft){
        offset = point.x;
    }else if(orientation == UIInterfaceOrientationLandscapeRight){
        offset = -point.x;
    }else if(orientation == UIInterfaceOrientationPortraitUpsideDown){
        offset = -point.y;
    }
    return offset;
}

@end
