//
//  SHKJSONSerializer.m
//  Smooch
//
//  Created by Mike Spensieri on 2014-09-29.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKJSONSerializer.h"

@implementation SHKJSONSerializer

- (NSData*)serializeRequest:(NSMutableURLRequest *)request
          withParameters:(id)parameters
                   error:(NSError * __autoreleasing *)error
{
    if([[request HTTPMethod] isEqualToString:@"GET"]){
        [self addQueryStringToRequest:request withParameters:parameters];
        return nil;
    }
    
    if (parameters) {
        if (![request valueForHTTPHeaderField:@"Content-Type"]) {
            NSString *charset = (__bridge NSString *)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
            [request setValue:[NSString stringWithFormat:@"application/json; charset=%@", charset] forHTTPHeaderField:@"Content-Type"];
        }
        
        return [NSJSONSerialization dataWithJSONObject:parameters options:0 error:error];
    }
    
    return nil;
}

- (id)responseObjectForResponse:(NSHTTPURLResponse *)response
                           data:(NSData *)data
                          error:(NSError *__autoreleasing *)error
{
    if (![self isValidContentType:[response MIMEType] data:data]) {
        *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotDecodeContentData userInfo:nil];
        return nil;
    }
    
    NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (responseString && ![responseString isEqualToString:@" "]) {
        // Workaround for a bug in NSJSONSerialization when Unicode character escape codes are used instead of the actual character
        // See http://stackoverflow.com/a/12843465/157142
        data = [responseString dataUsingEncoding:NSUTF8StringEncoding];
        
        if (data) {
            if ([data length] > 0) {
                return [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
            } else {
                return nil;
            }
        } else {
            *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotDecodeContentData userInfo:nil];
        }
    }
    
    return nil;
}

- (BOOL)isValidContentType:(NSString*)mimeType data:(NSData*)data
{
    NSSet* acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", nil];
    
    BOOL hasData = data.length > 0;
    BOOL validContentType = [acceptableContentTypes containsObject:mimeType];
    
    return !hasData || (hasData && validContentType);
}

@end