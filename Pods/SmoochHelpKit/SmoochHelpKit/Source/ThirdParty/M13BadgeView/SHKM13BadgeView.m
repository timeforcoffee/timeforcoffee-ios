//
//  M13BadgeView.m
//  M13BadgeView
//
/*Copyright (c) 2014 Brandon McQuilkin
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "SHKM13BadgeView.h"
#import <QuartzCore/QuartzCore.h>

@implementation SHKM13BadgeView
{
    BOOL autoSetCornerRadius;
    CATextLayer *textLayer;
    CAShapeLayer *backgroundLayer;
}

- (id)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup
{
    //Set the view properties
    self.backgroundColor = [UIColor clearColor];
    self.userInteractionEnabled = NO;
    self.clipsToBounds = NO;
    
    //Set the default
    _textColor = [UIColor whiteColor];
    _textAlignmentShift = CGSizeZero;
    _font = [UIFont systemFontOfSize:16.0];
    _badgeBackgroundColor = [UIColor redColor];
    _cornerRadius = self.frame.size.height / 2;
    _horizontalAlignment = SHKM13BadgeViewHorizontalAlignmentRight;
    _verticalAlignment = SHKM13BadgeViewVerticalAlignmentTop;
    _alignmentShift = CGSizeMake(0, 0);
    _animateChanges = YES;
    _animationDuration = 0.2;
    _hidesWhenZero = NO;
    
    //Set the minimum width / height if necessary;
    if (self.frame.size.height == 0 ) {
        CGRect frame = self.frame;
        frame.size.height = 24.0;
        _minimumWidth = 24.0;
        self.frame = frame;
    } else {
        _minimumWidth = self.frame.size.height;
    }
    
    _maximumWidth = CGFLOAT_MAX;
    
    //Create the text layer
    textLayer = [CATextLayer layer];
    textLayer.foregroundColor = _textColor.CGColor;
    textLayer.font = (__bridge CFTypeRef)(_font.fontName);
    textLayer.fontSize = _font.pointSize;
    textLayer.alignmentMode = kCAAlignmentCenter;
    textLayer.truncationMode = kCATruncationEnd;
    textLayer.wrapped = NO;
    textLayer.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    textLayer.contentsScale = [UIScreen mainScreen].scale;
    
    //Create the background layer
    backgroundLayer = [CAShapeLayer layer];
    backgroundLayer.fillColor = _badgeBackgroundColor.CGColor;
    backgroundLayer.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    backgroundLayer.contentsScale = [UIScreen mainScreen].scale;
    
    [self.layer addSublayer:backgroundLayer];
    [self.layer addSublayer:textLayer];
    
    //Setup animations
    CABasicAnimation *frameAnimation = [CABasicAnimation animation];
    frameAnimation.duration = _animationDuration;
    frameAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    NSDictionary *actions = @{@"path": frameAnimation};
    
    //Animate the path changes
    backgroundLayer.actions = actions;
}

#pragma mark layout

- (void)autoSetBadgeFrame
{
    CGRect frame = self.frame;
    
    //Get the width for the current string
    frame.size.width = [self sizeForString:_text includeBuffer:YES].width;
    if (frame.size.width < _minimumWidth) {
        frame.size.width = _minimumWidth;
    } else if (frame.size.width > _maximumWidth) {
        frame.size.width = _maximumWidth;
    }
    
    //Height doesn't need changing
    
    //Fix horizontal alignment if necessary
    if (_horizontalAlignment == SHKM13BadgeViewHorizontalAlignmentLeft) {
        frame.origin.x = 0 - (frame.size.width / 2) + _alignmentShift.width;
    } else if (_horizontalAlignment == SHKM13BadgeViewHorizontalAlignmentCenter) {
        frame.origin.x = (self.superview.bounds.size.width / 2) - (frame.size.width / 2) + _alignmentShift.width;
    } else if (_horizontalAlignment == SHKM13BadgeViewHorizontalAlignmentRight) {
        frame.origin.x = self.superview.bounds.size.width - (frame.size.width / 2) + _alignmentShift.width;
    }
    
    //Fix vertical alignment if necessary
    if (_verticalAlignment == SHKM13BadgeViewVerticalAlignmentTop) {
        frame.origin.y = 0 - (frame.size.height / 2) + _alignmentShift.height;
    } else if (_verticalAlignment == SHKM13BadgeViewVerticalAlignmentMiddle) {
        frame.origin.y = (self.superview.bounds.size.height / 2) - (frame.size.height / 2.0) + _alignmentShift.height;
    } else if (_verticalAlignment == SHKM13BadgeViewVerticalAlignmentBottom) {
        frame.origin.y = self.superview.bounds.size.height - (frame.size.height / 2.0) + _alignmentShift.height;
    }
    
    //Set the corner radius
    if (autoSetCornerRadius) {
        _cornerRadius = self.frame.size.height / 2;
    }
    
    //Constrain to integers
    frame = CGRectMake(ceilf(frame.origin.x), ceilf(frame.origin.y), ceilf(frame.size.width), ceilf(frame.size.height));
    
    //Change the frame
    self.frame = frame;
    CGRect tempFrame = CGRectMake(0, 0, frame.size.width, frame.size.height);
    backgroundLayer.frame = tempFrame;
    CGRect textFrame = CGRectMake(self.textAlignmentShift.width, (ceilf(self.frame.size.height - _font.lineHeight) / 2) + self.textAlignmentShift.height, self.frame.size.width, _font.lineHeight);
    textLayer.frame = textFrame;
    //Update the paths of the layers
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:tempFrame cornerRadius:_cornerRadius];
    backgroundLayer.path = path.CGPath;
}

- (CGSize)sizeForString:(NSString *)string includeBuffer:(BOOL)include
{
    if (!_font) {
        return CGSizeMake(0, 0);
    }
    //Calculate the width of the text
    CGFloat widthPadding = ceilf(_font.pointSize * .375);
    
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:(string ? string : @"") attributes:@{NSFontAttributeName : _font}];
                                                                                                          
    CGSize textSize = [attributedString boundingRectWithSize:(CGSize){CGFLOAT_MAX, CGFLOAT_MAX} options:NSStringDrawingUsesLineFragmentOrigin context:nil].size;
    
    if (include) {
        textSize.width += widthPadding * 2;
    }
    //Constrain to integers
    textSize.width = ceilf(textSize.width);
    textSize.height = ceilf(textSize.height);
    return textSize;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    //Update the frames of the layers
    CGRect textFrame = CGRectMake(self.textAlignmentShift.width, (ceilf(self.frame.size.height - _font.lineHeight) / 2) + self.textAlignmentShift.height, self.frame.size.width, _font.lineHeight);
    textLayer.frame = textFrame;
    backgroundLayer.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
    
    //Update the layer's paths
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:_cornerRadius];
    backgroundLayer.path = path.CGPath;
}

#pragma mark setting

- (void)setText:(NSString *)text
{
    _text = text;
    //If the new text is shorter, display the new text before shrinking
    if ([self sizeForString:textLayer.string includeBuffer:YES].width >= [self sizeForString:text includeBuffer:YES].width) {
        textLayer.string = text;
        [self setNeedsDisplay];
    } else {
        //If longer display new text after the animation
        if (_animateChanges) {
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_animationDuration * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                textLayer.string = text;
            });
        } else {
            textLayer.string = text;
        }
    }
    //Update the frame
    [self autoSetBadgeFrame];
    
    //Hide badge if text is zero
    [self hideForZeroIfNeeded];
}

- (void)setTextColor:(UIColor *)textColor
{
    _textColor = textColor;
    textLayer.foregroundColor = _textColor.CGColor;
}

- (void)setFont:(UIFont *)font
{
    _font = font;
    textLayer.fontSize = font.pointSize;
    textLayer.font = (__bridge CFTypeRef)(font.fontName);
    //Frame size needs to be changed to match the new font
    [self autoSetBadgeFrame];
}

- (void)setAnimateChanges:(BOOL)animateChanges
{
    _animateChanges = animateChanges;
    if (_animateChanges) {
        //Setup animations
        CABasicAnimation *frameAnimation = [CABasicAnimation animation];
        frameAnimation.duration = _animationDuration;
        frameAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
        NSDictionary *actions = @{@"path": frameAnimation};
        
        //Animate the path changes
        backgroundLayer.actions = actions;
    } else {
        backgroundLayer.actions = nil;
    }
}

- (void)setBadgeBackgroundColor:(UIColor *)badgeBackgroundColor
{
    _badgeBackgroundColor = badgeBackgroundColor;
    backgroundLayer.fillColor = _badgeBackgroundColor.CGColor;
}

- (void)setCornerRadius:(CGFloat)cornerRadius
{
    _cornerRadius = cornerRadius;
    autoSetCornerRadius = NO;
    //Update boackground
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:_cornerRadius];
    backgroundLayer.path = path.CGPath;
}

- (void)setHorizontalAlignment:(SHKM13BadgeViewHorizontalAlignment)horizontalAlignment
{
    _horizontalAlignment = horizontalAlignment;
    [self autoSetBadgeFrame];
}

- (void)setVerticalAlignment:(SHKM13BadgeViewVerticalAlignment)verticalAlignment
{
    _verticalAlignment = verticalAlignment;
    [self autoSetBadgeFrame];
}

- (void)setAlignmentShift:(CGSize)alignmentShift
{
    _alignmentShift = alignmentShift;
    [self autoSetBadgeFrame];
}

- (void)setMinimumWidth:(CGFloat)minimumWidth
{
    _minimumWidth = minimumWidth;
    [self autoSetBadgeFrame];
}

- (void)setMaximumWidth:(CGFloat)maximumWidth
{
    if (maximumWidth < self.frame.size.height) {
        maximumWidth = self.frame.size.height;
    }
    _maximumWidth = maximumWidth;
    [self autoSetBadgeFrame];
    [self setNeedsDisplay];
}

- (void)setHidesWhenZero:(BOOL)hidesWhenZero{
    _hidesWhenZero = hidesWhenZero;
    [self hideForZeroIfNeeded];
}

#pragma mark - Private

- (void)hideForZeroIfNeeded{
    self.hidden = ([_text isEqualToString:@"0"] && _hidesWhenZero);
}

@end
