//
//  SHKImageLoader.m
//  Smooch
//
//  Created by Mike Spensieri on 2014-11-04.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKImageLoader.h"
#import "SHKUtility.h"

@interface SHKImageLoadRequest : NSObject

@property NSString* url;
@property NSMutableArray* completionBlocks;

@end

@implementation SHKImageLoadRequest
@end

@interface SHKImageLoader()

@property NSMutableArray* queuedRequests;
@property SHKImageLoadRequest* activeRequest;
@property NSCache* imageCache;

@end

@implementation SHKImageLoader

- (instancetype)initWithStrategy:(id<SHKImageLoaderStrategy>)strategy
{
    self = [super init];
    if (self) {
        _strategy = strategy;
        _queuedRequests = [NSMutableArray new];
        _imageCache = [[NSCache alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)loadImageForUrl:(NSString *)urlString withCompletion:(SHKImageLoaderCompletionBlock)completion
{
    if(completion == nil){
        return;
    }else if(urlString == nil){
        completion(nil);
        return;
    }
    
    if([self.imageCache objectForKey:urlString] == nil){
        SHKImageLoadRequest* request = [[SHKImageLoadRequest alloc] init];
        request.url = urlString;
        request.completionBlocks = [NSMutableArray arrayWithObject:completion];
        
        [self queueRequest:request];
    }else{
        completion([self.imageCache objectForKey:urlString]);
    }
}

-(void)queueRequest:(SHKImageLoadRequest*)request
{
    @synchronized(self){
        // Do not request the same URL twice, just add the completion handler to the existing request
        SHKImageLoadRequest* existingRequest;
        if([self.activeRequest.url isEqualToString:request.url]){
            existingRequest = self.activeRequest;
        }else{
            existingRequest = [self queuedRequestForUrl:request.url];
        }
        
        if(existingRequest){
            [existingRequest.completionBlocks addObjectsFromArray:request.completionBlocks];
        }else{
            [self.queuedRequests addObject:request];
            [self dequeueAndPerformRequest];
        }
    }
}

-(void)dequeueAndPerformRequest
{
    @synchronized(self){
        if(self.activeRequest == nil && self.queuedRequests.count > 0){
            self.activeRequest = self.queuedRequests.firstObject;
            [self.queuedRequests removeObject:self.activeRequest];
            
            if([self.imageCache objectForKey:self.activeRequest.url] == nil){
                __weak typeof(self) weakSelf = self;
                [self.strategy loadImageForUrl:self.activeRequest.url withCompletion:^(UIImage *image) {
                    __strong typeof(self) strongSelf = weakSelf;
                    if(image && strongSelf.activeRequest.url){
                        [strongSelf.imageCache setObject:image forKey:strongSelf.activeRequest.url];
                    }
                    [strongSelf completeRequestWithImage:image];
                }];
            }else{
                [self completeRequestWithImage:[self.imageCache objectForKey:self.activeRequest.url]];
            }
        }
    }
}

-(void)completeRequestWithImage:(UIImage*)image
{
    @synchronized(self){
        SHKImageLoadRequest* completedRequest = self.activeRequest;
        SHKEnsureMainThread(^{
            for(SHKImageLoaderCompletionBlock completionBlock in completedRequest.completionBlocks){
                completionBlock(image);
            }
        });
        
        self.activeRequest = nil;
        [self dequeueAndPerformRequest];
    }
}

-(SHKImageLoadRequest*)queuedRequestForUrl:(NSString*)url
{
    for(SHKImageLoadRequest* queuedRequest in self.queuedRequests){
        if([queuedRequest.url isEqualToString:url]){
            return queuedRequest;
        }
    }
    return nil;
}

-(void)cacheImage:(UIImage *)image forUrl:(NSString *)urlString
{
    if(image && urlString){
        [self.imageCache setObject:image forKey:urlString];
    }
}

-(UIImage*)cachedImageForUrl:(NSString *)urlString
{
    return [self.imageCache objectForKey:urlString];
}

-(void)clearImageCache
{
    [self.imageCache removeAllObjects];
}

-(void)didReceiveMemoryWarning
{
    [self clearImageCache];
}

@end
