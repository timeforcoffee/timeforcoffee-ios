//
//  SHKSearchResult.h
//  Smooch
//
//  Created by Joel Simpson on 2014-04-29.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SHKSearchResult : NSObject

-(instancetype)initWithTitle:(NSString*)title url:(NSString*)url;
-(instancetype)initWithDictionary:(NSDictionary*)jsonResult;

@property NSString* htmlURL;
@property NSString* title;
@property NSNumber* sectionId;

@end
