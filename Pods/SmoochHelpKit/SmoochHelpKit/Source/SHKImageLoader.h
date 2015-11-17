//
//  SHKImageLoader.h
//  Smooch
//
//  Created by Mike Spensieri on 2014-11-04.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
@protocol SHKImageLoaderStrategy;

typedef void (^SHKImageLoaderCompletionBlock)(UIImage* image);

@interface SHKImageLoader : NSObject

-(instancetype)initWithStrategy:(id<SHKImageLoaderStrategy>)strategy;

-(void)loadImageForUrl:(NSString*)urlString withCompletion:(SHKImageLoaderCompletionBlock)completion;
-(void)cacheImage:(UIImage*)image forUrl:(NSString*)urlString;
-(UIImage*)cachedImageForUrl:(NSString*)urlString;
-(void)clearImageCache;

@property id<SHKImageLoaderStrategy> strategy;

@end

@protocol SHKImageLoaderStrategy <NSObject>

-(void)loadImageForUrl:(NSString*)urlString withCompletion:(SHKImageLoaderCompletionBlock)completion;

@end
