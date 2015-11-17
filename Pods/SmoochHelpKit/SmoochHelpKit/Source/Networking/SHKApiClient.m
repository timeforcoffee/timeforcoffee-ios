//
//  SHKApiClient.m
//  Smooch
//
//  Created by Mike Spensieri on 2014-09-29.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKApiClient.h"
#import "SHKJSONSerializer.h"
#import <UIKit/UIKit.h>
#import "SHKUtility.h"

@interface SHKApiClient() < NSURLSessionTaskDelegate >

@property NSURLSession* session;
@property NSMutableDictionary* headerFields;
@property SHKJSONSerializer* serializer;
@property NSMutableDictionary* progressBlocks;

@end

@implementation SHKApiClient

- (instancetype)init
{
    return [self initWithBaseURL:nil];
}

-(instancetype)initWithBaseURL:(NSString *)url
{
    self = [super init];
    if(self){
        _progressBlocks = [[NSMutableDictionary alloc] init];
        _baseURL = [NSURL URLWithString:url];
        _expectJSONResponse = YES;
        _serializer = [[SHKJSONSerializer alloc] init];
        
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil];
        
        // User-Agent Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.43
        NSString *userAgent = [NSString stringWithFormat:@"%@/%@ (%@; iOS %@; Scale/%0.2f)", [[[NSBundle mainBundle] infoDictionary] objectForKey:(__bridge NSString *)kCFBundleExecutableKey] ?: [[[NSBundle mainBundle] infoDictionary] objectForKey:(__bridge NSString *)kCFBundleIdentifierKey], (__bridge id)CFBundleGetValueForInfoDictionaryKey(CFBundleGetMainBundle(), kCFBundleVersionKey) ?: [[[NSBundle mainBundle] infoDictionary] objectForKey:(__bridge NSString *)kCFBundleVersionKey], [[UIDevice currentDevice] model], [[UIDevice currentDevice] systemVersion], [[UIScreen mainScreen] scale]];
        if (userAgent) {
            if (![userAgent canBeConvertedToEncoding:NSASCIIStringEncoding]) {
                NSMutableString *mutableUserAgent = [userAgent mutableCopy];
                if (CFStringTransform((__bridge CFMutableStringRef)(mutableUserAgent), NULL, (__bridge CFStringRef)@"Any-Latin; Latin-ASCII; [:^ASCII:] Remove", false)) {
                    userAgent = mutableUserAgent;
                }
            }
            
            _headerFields = [NSMutableDictionary dictionaryWithDictionary:@{ @"User-Agent" : userAgent }];
        }else{
            _headerFields = [NSMutableDictionary dictionary];
        }
    }
    return self;
}

-(void)setValue:(id)value forHTTPHeaderField:(NSString *)field
{
    [self.headerFields setObject:value forKey:field];
}

-(NSURLSessionDataTask*)GET:(NSString *)URLString parameters:(id)parameters completion:(SHKApiClientCompletionBlock)completion
{
    return [self requestWithMethod:@"GET" url:URLString parameters:parameters completion:completion];
}

-(NSURLSessionDataTask*)requestWithMethod:(NSString *)method url:(NSString *)URLString parameters:(id)parameters completion:(SHKApiClientCompletionBlock)completion
{
    return [self requestWithMethod:method url:URLString parameters:parameters image:nil completion:completion];
}

-(NSURLSessionDataTask*)uploadImage:(UIImage *)image url:(NSString *)urlString completion:(SHKApiClientCompletionBlock)completion
{
    return [self uploadImage:image url:urlString progress:nil completion:completion];
}

-(NSURLSessionDataTask*)uploadImage:(UIImage *)image url:(NSString *)urlString progress:(SHKApiClientUploadProgressBlock)progress completion:(SHKApiClientCompletionBlock)completion
{
    NSURLSessionDataTask* task = [self requestWithMethod:@"POST" url:urlString parameters:nil image:image completion:completion];
    if(progress){
        [self.progressBlocks setObject:progress forKey:[NSString stringWithFormat:@"%ld", (unsigned long)task.taskIdentifier]];
    }
    return task;
}

-(NSURLSessionDataTask*)requestWithMethod:(NSString *)method url:(NSString *)URLString parameters:(id)parameters image:(UIImage*)image completion:(SHKApiClientCompletionBlock)completion
{
    NSMutableURLRequest* mutableRequest = [self newRequestWithMethod:method url:URLString];
    
    NSError* serializationError;
    
    NSData* bodyData;
    if(image){
        bodyData = [self.serializer serializeRequest:mutableRequest withImage:image error:&serializationError];
    }else{
        bodyData = [self.serializer serializeRequest:mutableRequest withParameters:parameters error:&serializationError];
    }
    
    if(serializationError){
        if(completion){
            completion(nil, serializationError, nil);
        }
        return nil;
    }
    
    __block NSURLSessionDataTask* task;
    void (^doneBlock)(NSData *data, NSURLResponse *response, NSError *error) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        [self requestCompletedForTask:task withData:data response:(NSHTTPURLResponse*)response error:error completion:completion];
    };
    
    if(image){
        task = [self.session uploadTaskWithRequest:mutableRequest fromData:bodyData completionHandler:doneBlock];
    }else{
        if(bodyData && bodyData.length > 0){
            mutableRequest.HTTPBody = bodyData;
        }
        task = [self.session dataTaskWithRequest:mutableRequest completionHandler:doneBlock];
    }
    
    [task resume];
    
    return task;
}

-(NSMutableURLRequest*)newRequestWithMethod:(NSString*)method url:(NSString*)urlString
{
    BOOL isFullyQualifiedURL = [urlString rangeOfString:@"http://"].location != NSNotFound || [urlString rangeOfString:@"https://"].location != NSNotFound;
    
    NSURL *url;
    if(isFullyQualifiedURL){
        url = [NSURL URLWithString:urlString];
    }else{
        url = [NSURL URLWithString:urlString relativeToURL:self.baseURL];
    }
    
    NSMutableURLRequest *mutableRequest = [[NSMutableURLRequest alloc] initWithURL:url];
    mutableRequest.HTTPMethod = method;
    
    [self.headerFields enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL * __unused stop) {
        if (![mutableRequest valueForHTTPHeaderField:field]) {
            [mutableRequest setValue:value forHTTPHeaderField:field];
        }
    }];
    
    return mutableRequest;
}

-(void)requestCompletedForTask:(NSURLSessionDataTask*)task withData:(NSData*)data response:(NSHTTPURLResponse*)response error:(NSError*)error completion:(SHKApiClientCompletionBlock)completion
{
    [self.progressBlocks removeObjectForKey:[NSString stringWithFormat:@"%ld", (unsigned long)task.taskIdentifier]];
    
    if(!error && ![self isValidStatusCode:response]){
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Bad status code : %ld %@",  (long)response.statusCode, [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode]]
                                   };
        
        error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:userInfo];
    }
    
    id responseObject = data;
    
    if(self.expectJSONResponse){
        NSError* serializationError;
        responseObject = [self.serializer responseObjectForResponse:response data:data error:&serializationError];
        
        if(serializationError){
            error = serializationError;
            responseObject = nil;
        }
    }
    
    if(completion){
        completion(task, error, responseObject);
    }
}

- (BOOL)isValidStatusCode:(NSHTTPURLResponse *)response
{
    NSIndexSet* acceptableStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
    return response && [acceptableStatusCodes containsIndex:(NSUInteger)response.statusCode];
}

-(void)dealloc
{
    [self.session invalidateAndCancel];
}

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionDataTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    NSString* taskIdentifier = [NSString stringWithFormat:@"%ld", (unsigned long)task.taskIdentifier];
    SHKApiClientUploadProgressBlock progressBlock = (SHKApiClientUploadProgressBlock)self.progressBlocks[taskIdentifier];
    
    if(progressBlock){
        SHKEnsureMainThread(^{
            progressBlock((double)totalBytesSent / (double)totalBytesExpectedToSend);
        });
    }
}

@end
