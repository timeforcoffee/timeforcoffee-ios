//
//  HTMLParser.h
//  StackOverflow
//
//  Created by Ben Reeves on 09/03/2010.
//  Copyright 2010 Ben Reeves. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libxml/HTMLparser.h>
//#import "HTMLNode.h"

@class SHKHTMLNode;

@interface SHKHTMLParser : NSObject 
{
	@public
	htmlDocPtr _doc;
}

-(id)initWithContentsOfURL:(NSURL*)url error:(NSError**)error;
-(id)initWithData:(NSData*)data error:(NSError**)error;
-(id)initWithString:(NSString*)string error:(NSError**)error;

//Returns the doc tag
-(SHKHTMLNode*)doc;

//Returns the body tag
-(SHKHTMLNode*)body;

//Returns the html tag
-(SHKHTMLNode*)html;

//Returns the head tag
- (SHKHTMLNode*)head;

@end
