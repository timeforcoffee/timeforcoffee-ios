//
//  SHKSearchFallbackStrategy.h
//  Smooch
//
//  Created by Mike Spensieri on 2014-10-14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SHKSearchEndpointFactory.h"
@class SHKSearchClient;

@interface SHKSearchFallbackStrategy : NSObject

-(instancetype)initWithSearchClient:(SHKSearchClient *)client factory:(SHKSearchEndpointFactory*)factory;

-(void)search:(NSString*)query withCompletion:(void (^)(NSArray *results, NSError *error))completion;

@property SHKZendeskApiEndpoint apiEndpoint;
@property SHKSearchClient* searchClient;

@end
