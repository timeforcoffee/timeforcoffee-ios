//
//  SHKLocalization.m
//  Smooch
//
//  Created by Michael Spensieri on 11/12/13.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKLocalization.h"
#import "SmoochHelpKit+Private.h"

static NSString* const kStringFile = @"SHKLocalizable";
static NSString* const kNotFound = @"StringNotFound";

@implementation SHKLocalization

+(NSString*)localizedStringForKey:(NSString*)key
{
    NSString* localized = [[NSBundle mainBundle] localizedStringForKey:key value:kNotFound table:kStringFile];
    
    if(localized && ![localized isEqualToString:kNotFound]){
        return localized;
    }
    
    localized = [[SmoochHelpKit getResourceBundle] localizedStringForKey:key value:kNotFound table:kStringFile];
    
    if(localized && ![localized isEqualToString:kNotFound]){
        return localized;
    }
    
    return key;
}

@end
