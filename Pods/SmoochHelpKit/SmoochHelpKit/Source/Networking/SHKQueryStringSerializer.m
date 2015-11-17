//
//  SHKQueryStringSerializer.m
//  Smooch
//
//  Created by Mike Spensieri on 2014-09-29.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKQueryStringSerializer.h"

static const CGFloat kImageMaxSize = 1280;
static const CGFloat kImageJPEGCompressionQuality = 0.75;

static NSString * SHKAFQueryStringFromParametersWithEncoding(NSDictionary *parameters, NSStringEncoding stringEncoding);

static NSString * SHKAFCreateMultipartFormBoundary() {
    return [NSString stringWithFormat:@"Boundary+%08X%08X", arc4random(), arc4random()];
}

static NSString * const kSHKAFMultipartFormCRLF = @"\r\n";

@implementation SHKQueryStringSerializer

-(void)addQueryStringToRequest:(NSMutableURLRequest*)request withParameters:(id)parameters
{
    if(parameters){
        NSString* query = SHKAFQueryStringFromParametersWithEncoding(parameters, NSUTF8StringEncoding);
        
        if([[request HTTPMethod] isEqualToString:@"GET"]){
            request.URL = [NSURL URLWithString:[[request.URL absoluteString] stringByAppendingFormat:request.URL.query ? @"&%@" : @"?%@", query]];
        }else{
            if (![request valueForHTTPHeaderField:@"Content-Type"]) {
                [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
            }
            [request setHTTPBody:[query dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
}

-(NSData*)serializeRequest:(NSMutableURLRequest *)request withImage:(UIImage*)image error:(NSError *__autoreleasing *)error
{
    NSData* imageData = UIImageJPEGRepresentation([self scaleDownImage:image], kImageJPEGCompressionQuality);
    
    if(!image || !imageData || imageData.length == 0){
        *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotDecodeRawData userInfo:nil];
        return nil;
    }
    
    NSString *boundary = SHKAFCreateMultipartFormBoundary();
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",boundary];
    [request addValue:contentType forHTTPHeaderField: @"Content-Type"];
    
    NSMutableData *body = [NSMutableData data];
    [body appendData:[[NSString stringWithFormat:@"%@--%@%@", kSHKAFMultipartFormCRLF, boundary, kSHKAFMultipartFormCRLF] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"source\"; filename=\"image.jpg\"%@", kSHKAFMultipartFormCRLF] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Type: image/jpeg%@%@", kSHKAFMultipartFormCRLF, kSHKAFMultipartFormCRLF] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:imageData];
    [body appendData:[[NSString stringWithFormat:@"%@--%@--%@", kSHKAFMultipartFormCRLF, boundary, kSHKAFMultipartFormCRLF] dataUsingEncoding:NSUTF8StringEncoding]];
    
    if(body && body.length > 0){
        return body;
    }else{
        *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotDecodeRawData userInfo:nil];
        return  nil;
    }
}

-(UIImage*)scaleDownImage:(UIImage*)image
{
    const CGFloat maxSize = kImageMaxSize;
    CGFloat scaleFactor;
    
    CGSize imageSize = image.size;
    if(imageSize.width > imageSize.height){
        if(imageSize.width <= maxSize){
            return image;
        }
        
        scaleFactor = (maxSize / imageSize.width);
    }else{
        if(imageSize.height <= maxSize){
            return image;
        }
        
        scaleFactor = (maxSize / imageSize.height);
    }
    
    CGSize newSize = CGSizeMake(imageSize.width * scaleFactor, imageSize.height * scaleFactor);

    UIGraphicsBeginImageContextWithOptions(newSize, NO, 1.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

@end

#pragma mark - Query String Creation (Stolen from AFNetworking)

@interface SHKAFQueryStringPair : NSObject

@property (readwrite, nonatomic, strong) id field;
@property (readwrite, nonatomic, strong) id value;

- (id)initWithField:(id)field value:(id)value;

- (NSString *)URLEncodedStringValueWithEncoding:(NSStringEncoding)stringEncoding;

@end

NSArray * SHKAFQueryStringPairsFromKeyAndValue(NSString *key, id value) {
    NSMutableArray *mutableQueryStringComponents = [NSMutableArray array];
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"description" ascending:YES selector:@selector(compare:)];
    
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = value;
        // Sort dictionary keys to ensure consistent ordering in query string, which is important when deserializing potentially ambiguous sequences, such as an array of dictionaries
        for (id nestedKey in [dictionary.allKeys sortedArrayUsingDescriptors:@[ sortDescriptor ]]) {
            id nestedValue = [dictionary objectForKey:nestedKey];
            if (nestedValue) {
                [mutableQueryStringComponents addObjectsFromArray:SHKAFQueryStringPairsFromKeyAndValue((key ? [NSString stringWithFormat:@"%@[%@]", key, nestedKey] : nestedKey), nestedValue)];
            }
        }
    } else if ([value isKindOfClass:[NSArray class]]) {
        NSArray *array = value;
        for (id nestedValue in array) {
            [mutableQueryStringComponents addObjectsFromArray:SHKAFQueryStringPairsFromKeyAndValue([NSString stringWithFormat:@"%@[]", key], nestedValue)];
        }
    } else if ([value isKindOfClass:[NSSet class]]) {
        NSSet *set = value;
        for (id obj in [set sortedArrayUsingDescriptors:@[ sortDescriptor ]]) {
            [mutableQueryStringComponents addObjectsFromArray:SHKAFQueryStringPairsFromKeyAndValue(key, obj)];
        }
    } else {
        [mutableQueryStringComponents addObject:[[SHKAFQueryStringPair alloc] initWithField:key value:value]];
    }
    
    return mutableQueryStringComponents;
}

NSArray * SHKAFQueryStringPairsFromDictionary(NSDictionary *dictionary) {
    return SHKAFQueryStringPairsFromKeyAndValue(nil, dictionary);
}

static NSString * SHKAFQueryStringFromParametersWithEncoding(NSDictionary *parameters, NSStringEncoding stringEncoding) {
    NSMutableArray *mutablePairs = [NSMutableArray array];
    for (SHKAFQueryStringPair *pair in SHKAFQueryStringPairsFromDictionary(parameters)) {
        [mutablePairs addObject:[pair URLEncodedStringValueWithEncoding:stringEncoding]];
    }
    
    return [mutablePairs componentsJoinedByString:@"&"];
}

static NSString * const kSHKAFCharactersToBeEscapedInQueryString = @":/?&=;+!@#$()',*";

static NSString * SHKAFPercentEscapedQueryStringValueFromStringWithEncoding(NSString *string, NSStringEncoding encoding) {
    return (__bridge_transfer  NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)string, NULL, (__bridge CFStringRef)kSHKAFCharactersToBeEscapedInQueryString, CFStringConvertNSStringEncodingToEncoding(encoding));
}

static NSString * SHKAFPercentEscapedQueryStringKeyFromStringWithEncoding(NSString *string, NSStringEncoding encoding) {
    static NSString * const kSHKAFCharactersToLeaveUnescapedInQueryStringPairKey = @"[].";
    
    return (__bridge_transfer  NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)string, (__bridge CFStringRef)kSHKAFCharactersToLeaveUnescapedInQueryStringPairKey, (__bridge CFStringRef)kSHKAFCharactersToBeEscapedInQueryString, CFStringConvertNSStringEncodingToEncoding(encoding));
}

@implementation SHKAFQueryStringPair

- (id)initWithField:(id)field value:(id)value {
    self = [super init];
    if (self) {
        _field = field;
        _value = value;
    }
    return self;
}

- (NSString *)URLEncodedStringValueWithEncoding:(NSStringEncoding)stringEncoding {
    if (!self.value || [self.value isEqual:[NSNull null]]) {
        return SHKAFPercentEscapedQueryStringKeyFromStringWithEncoding([self.field description], stringEncoding);
    } else {
        return [NSString stringWithFormat:@"%@=%@", SHKAFPercentEscapedQueryStringKeyFromStringWithEncoding([self.field description], stringEncoding), SHKAFPercentEscapedQueryStringValueFromStringWithEncoding([self.value description], stringEncoding)];
    }
}

@end
