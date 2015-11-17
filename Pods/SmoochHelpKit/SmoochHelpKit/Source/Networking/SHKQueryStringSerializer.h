//
//  SHKQueryStringSerializer.h
//  Smooch
//
//  Created by Mike Spensieri on 2014-09-29.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SHKQueryStringSerializer : NSObject

-(void)addQueryStringToRequest:(NSMutableURLRequest*)request withParameters:(id)parameters;
-(NSData*)serializeRequest:(NSMutableURLRequest *)request withImage:(UIImage*)image error:(NSError *__autoreleasing *)error;

@end
