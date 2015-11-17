//
//  SHKAjaxEndpoint.h
//  Smooch
//
//  Created by Mike Spensieri on 2014-10-14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKSearchEndpoint.h"

@interface SHKAjaxEndpoint : NSObject < SHKSearchEndpoint >

-(instancetype)initWithKnowledgeBaseURL:(NSString*)knowledgeBaseURL;

-(NSArray*)parseHtmlResponse:(NSString*)response;

//Overrides
-(BOOL)failIfHeadIsPresent;

@end
