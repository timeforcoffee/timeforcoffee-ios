//
//  SHKAppColorExtractor.m
//  Smooch
//
//  Created by Jean-Philippe Joyal on 2/26/14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKAppColorExtractor.h"
#import "SHKLEColorPicker.h"
#import "SHKUtility.h"

#define SMOOCH_PRIMARY_GREY_COLOR_COMPONENT_VALUE (205.0/255.0)
#define SMOOCH_SECONDARY_GREY_COLOR_COMPONENT_VALUE (72.0/255.0)

NSString* const SHKAppColorUpdatedNotification = @"SHKAppColorUpdatedNotification";

@interface SHKAppColorExtractor()

@property UIColor* primaryAppColor;
@property UIColor* secondaryAppColor;
@property BOOL extractingColors;

@property dispatch_semaphore_t colorPickerLock;

@end

@implementation SHKAppColorExtractor

+ (SHKAppColorExtractor*) sharedInstance
{
	static SHKAppColorExtractor* SharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		SharedInstance = [SHKAppColorExtractor new];
	});
	
	return SharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
        
        self.colorPickerLock = dispatch_semaphore_create(1);
        
        // Default color is grey
        self.primaryAppColor = [UIColor colorWithRed:SMOOCH_PRIMARY_GREY_COLOR_COMPONENT_VALUE
                                               green:SMOOCH_PRIMARY_GREY_COLOR_COMPONENT_VALUE
                                                blue:SMOOCH_PRIMARY_GREY_COLOR_COMPONENT_VALUE
                                               alpha:1.0];
        self.secondaryAppColor = [UIColor colorWithRed:SMOOCH_SECONDARY_GREY_COLOR_COMPONENT_VALUE
                                                 green:SMOOCH_SECONDARY_GREY_COLOR_COMPONENT_VALUE
                                                  blue:SMOOCH_SECONDARY_GREY_COLOR_COMPONENT_VALUE
                                                 alpha:1.0];
    }
    return self;
}

- (BOOL) hasAppColors
{
    return self.primaryAppColor != nil && self.secondaryAppColor != nil;
}

// @synchronized(self) ensures we do not schedule another color pick if one is running
// self.colorPickerLock is used to make sure we do not do OpenGL calls if the app is backgrounded
- (void) extractAppColors{
    @synchronized(self){
        if(self.extractingColors){
            return;
        }
        self.extractingColors = YES;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage* image = SHKTakeScreenshotOfRootWindow();
        
        dispatch_semaphore_wait(self.colorPickerLock, DISPATCH_TIME_FOREVER);
        
        SHKLEColorScheme* colorScheme = [[SHKLEColorPicker new] colorSchemeFromImage:image];
        
        dispatch_semaphore_signal(self.colorPickerLock);
        
        if(SHKGetSaturationOfColor([colorScheme primaryTextColor]) >= SHKGetSaturationOfColor([colorScheme backgroundColor])){
            self.primaryAppColor = [colorScheme primaryTextColor];
            self.secondaryAppColor = [colorScheme backgroundColor];
        }else{
            self.primaryAppColor = [colorScheme backgroundColor];
            self.secondaryAppColor = [colorScheme primaryTextColor];
        }
        
        @synchronized(self){
            self.extractingColors = NO;
        }
        
        [self performSelectorOnMainThread:@selector(notify) withObject:nil waitUntilDone:NO];
    });
}

-(void)notify
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SHKAppColorUpdatedNotification object:nil];
}

-(UIColor*)lightenedPrimaryColor
{
    return [self colorByLighteningColor:self.primaryAppColor];
}

-(UIColor*)lightenedSecondaryColor
{
    return [self colorByLighteningColor:self.secondaryAppColor];
}

-(UIColor*)darkenedPrimaryColor
{
    return [self colorByDarkeningColor:self.primaryAppColor];
}
-(UIColor*)saturatedPrimaryColor
{
    return [self colorBySaturatingColor:self.primaryAppColor];
}

- (UIColor*)colorByDarkeningColor:(UIColor*)color
{
    CGFloat hue, saturation, brightness, alpha;
    [color getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
    
    // make it dark
    saturation = 0.24;
    brightness = 0.18;
    alpha = 0.85;
    
    return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
}

- (UIColor*)colorByLighteningColor:(UIColor*)color
{
    CGFloat hue, saturation, brightness, alpha;
    [color getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
    
    
    if(saturation < 0.1){
        brightness = 0.70;
    }else{
        if(saturation > 0.35){
            saturation = 0.35;
        }
        brightness = 0.75;
    }
    
    return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
}

// loading bar color
- (UIColor*)colorBySaturatingColor:(UIColor*)color
{
    CGFloat hue, saturation, brightness, alpha;
    [color getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
    
    saturation = 1.0;
    brightness = 0.6;
    
    return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
}

-(void)enterBackground
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    dispatch_semaphore_wait(self.colorPickerLock, DISPATCH_TIME_FOREVER);
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
}

-(void)enterForeground
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    dispatch_semaphore_signal(self.colorPickerLock);
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end


