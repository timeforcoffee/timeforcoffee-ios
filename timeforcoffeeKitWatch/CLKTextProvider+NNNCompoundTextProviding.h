//
//  CLKTextProvider+NNNCompoundTextProviding.h
//  timeforcoffee
//
//  Created by Christian Stocker on 20.09.18.
//  Copyright © 2018 opendata.ch. All rights reserved.
//

#ifndef CLKTextProvider_NNNCompoundTextProviding_h
#define CLKTextProvider_NNNCompoundTextProviding_h
#import <ClockKit/ClockKit.h>

@interface CLKTextProvider (NNNCompoundTextProviding)
    
+ (nonnull CLKTextProvider *)nnn_textProviderByJoiningProvider:(nonnull CLKTextProvider *)provider1 andProvider:(nonnull CLKTextProvider *)provider2 withString:(nullable NSString *)joinString;
+ (nonnull CLKTextProvider *)nnn_textProviderByJoiningProvider:(nonnull CLKTextProvider *)provider1 andProvider:(nonnull CLKTextProvider *)provider2 andProvider2:(nonnull CLKTextProvider *)provider3;
+ (CLKTextProvider *)textProviderByJoiningTextProviders: (NSArray<CLKTextProvider *> *)textProviders separator:(NSString * _Nullable) separator;
    @end

#endif /* CLKTextProvider_NNNCompoundTextProviding_h */
