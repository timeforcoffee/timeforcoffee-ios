//
//  CLKTextProvider+NNNCompoundTextProviding.m
//  Time for Coffee! WatchOS 2 App Extension
//
//  Created by Christian Stocker on 20.09.18.
//  Copyright © 2018 opendata.ch. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ClockKit/ClockKit.h>

@implementation CLKTextProvider (NNNCompoundTextProviding)
    
+ (nonnull CLKTextProvider *)nnn_textProviderByJoiningProvider:(nonnull CLKTextProvider *)provider1 andProvider:(nonnull CLKTextProvider *)provider2 withString:(nullable NSString *)joinString
    {
        NSString *textProviderToken = @"%@";
        
        NSString *formatString;
        
        if (joinString != nil) {
            formatString = [NSString stringWithFormat:@"%@%@%@",
                            textProviderToken,
                            joinString,
                            textProviderToken];
        }
        else {
            formatString = [NSString stringWithFormat:@"%@%@",
                            textProviderToken,
                            textProviderToken];
        }
        
        return [self textProviderWithFormat:formatString, provider1, provider2];
    }
    
+ (nonnull CLKTextProvider *)nnn_textProviderByJoiningProvider:(nonnull CLKTextProvider *)provider1 andProvider:(nonnull CLKTextProvider *)provider2 andProvider2:(nonnull CLKTextProvider *)provider3
{
    NSString *textProviderToken = @"%@";
    
    NSString *formatString;
    
    
    formatString = [NSString stringWithFormat:@"%@%@%@",
                    textProviderToken,
                    textProviderToken,
                    textProviderToken];
    
    
    return [self textProviderWithFormat:formatString, provider1, provider2, provider3];
}
    
+ (CLKTextProvider *)textProviderByJoiningTextProviders: (NSArray<CLKTextProvider *> *)textProviders separator:(NSString * _Nullable) separator {
    
    NSString *formatString = @"%@%@";
    
    if (separator.length > 0) {
        formatString = [NSString stringWithFormat:@"%@%@%@", @"%@", separator, @"%@"];
    }
    
    CLKTextProvider *firstItem = textProviders.firstObject;
    
    for (int index = 1; index < textProviders.count; index++) {
        CLKTextProvider *secondItem = [textProviders objectAtIndex: index];
        firstItem = [CLKTextProvider textProviderWithFormat:formatString, firstItem, secondItem];
    }
    
    return firstItem;
}
@end
