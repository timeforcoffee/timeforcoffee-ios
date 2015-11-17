//
//  SHKAjaxEndpoint.m
//  Smooch
//
//  Created by Mike Spensieri on 2014-10-14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKAjaxEndpoint.h"
#import "SHKHTMLParser.h"
#import "SHKHTMLNode.h"
#import "SHKSearchResult.h"
#import "SHKSettings.h"

@interface SHKAjaxEndpoint()

@property NSString* knowledgeBaseURL;

@end

@implementation SHKAjaxEndpoint

-(instancetype)initWithKnowledgeBaseURL:(NSString*)knowledgeBaseURL
{
    self = [super init];
    if (self) {
        _knowledgeBaseURL = knowledgeBaseURL;
    }
    return self;
}

-(NSString*)urlForQuery:(NSString *)query
{
    NSAssert(FALSE, @"Override this method!");
    return nil;
}

-(NSArray*)parseHtmlResponse:(NSString*)response
{
    NSError *error = nil;
    SHKHTMLParser *parser = [[SHKHTMLParser alloc] initWithString:response error:&error];
    
    // If head != nil, the response is a full HTML page, which may not be expected format
    BOOL unexpectedFormat = [parser head] != nil && [self failIfHeadIsPresent];
    
    if (error || unexpectedFormat){
        return nil;
    }
    
    NSMutableArray* results = [NSMutableArray array];
    
    SHKHTMLNode *bodyNode = [parser body];
    SHKHTMLNode* mainNode = [bodyNode findChildTag:@"main"];
    
    NSArray *linkNodes;
    if(mainNode){
        linkNodes = [mainNode findChildTags:@"a"];
    }else{
        linkNodes = [bodyNode findChildTags:@"a"];
    }
    
    for (SHKHTMLNode* linkNode in linkNodes) {
        NSString* href = [linkNode getAttributeNamed:@"href"];
        if (href && ![href isEqualToString:@"#"]){
            NSString* title =  [[linkNode contents] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([title length] > 0){
                NSString* link = [NSString stringWithFormat:@"%@%@", self.knowledgeBaseURL, href];
                [results addObject:[[SHKSearchResult alloc] initWithTitle:title url:link]];
            }
        }
    }
    
    return results;
}

-(BOOL)failIfHeadIsPresent
{
    return YES;
}

@end
