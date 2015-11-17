//
//  SHKJSONSerializer.h
//  Smooch
//
//  Created by Mike Spensieri on 2014-09-29.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SHKQueryStringSerializer.h"

@interface SHKJSONSerializer : SHKQueryStringSerializer

- (NSData*)serializeRequest:(NSMutableURLRequest *)request
                    withParameters:(id)parameters
                             error:(NSError * __autoreleasing *)error;

- (id)responseObjectForResponse:(NSHTTPURLResponse *)response
                           data:(NSData *)data
                          error:(NSError *__autoreleasing *)error;

@end
