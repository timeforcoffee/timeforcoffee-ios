//
//  SHKApiClient.h
//  Smooch
//
//  Created by Mike Spensieri on 2014-09-29.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void (^SHKApiClientCompletionBlock)(NSURLSessionDataTask *task, NSError *error, id responseObject);
typedef void (^SHKApiClientUploadProgressBlock)(double progress);

@interface SHKApiClient : NSObject

-(instancetype)initWithBaseURL:(NSString*)url;

@property BOOL expectJSONResponse;
@property NSURL* baseURL;

-(void)setValue:(id)value forHTTPHeaderField:(NSString *)field;

- (NSURLSessionDataTask *)GET:(NSString *)URLString
                   parameters:(id)parameters
                   completion:(SHKApiClientCompletionBlock)completion;

- (NSURLSessionUploadTask*)uploadImage:(UIImage*)image
                                   url:(NSString*)urlString
                            completion:(SHKApiClientCompletionBlock)completion;

-(NSURLSessionDataTask*)uploadImage:(UIImage *)image
                                url:(NSString *)urlString
                           progress:(SHKApiClientUploadProgressBlock)progress
                         completion:(SHKApiClientCompletionBlock)completion;

- (NSURLSessionDataTask *)requestWithMethod:(NSString*)method
                                        url:(NSString *)URLString
                                 parameters:(id)parameters
                                 completion:(SHKApiClientCompletionBlock)completion;

@end
