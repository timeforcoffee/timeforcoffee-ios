//
//  HTMLNode.h
//  StackOverflow
//
//  Created by Ben Reeves on 09/03/2010.
//  Copyright 2010 Ben Reeves. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libxml/HTMLparser.h>
#import "SHKHTMLParser.h"

@class SHKHTMLParser;

#define ParsingDepthUnlimited 0
#define ParsingDepthSame -1
#define ParsingDepth size_t

typedef enum
{
	HTMLHrefNode,
	HTMLTextNode,
	HTMLUnkownNode,
	HTMLCodeNode,
	HTMLSpanNode,
	HTMLPNode,
	HTMLLiNode,
	HTMLUlNode,
	HTMLImageNode,
	HTMLOlNode,
	HTMLStrongNode,
	HTMLPreNode,
	HTMLBlockQuoteNode,
} SHKHTMLNodeType;

@interface SHKHTMLNode : NSObject 
{
@public
	xmlNode * _node;
}

//Init with a lib xml node (shouldn't need to be called manually)
//Use [parser doc] to get the root Node
-(id)initWithXMLNode:(xmlNode*)xmlNode;

//Returns a single child of class
-(SHKHTMLNode*)findChildOfClass:(NSString*)className;

//Returns all children of class
-(NSArray*)findChildrenOfClass:(NSString*)className;

//Finds a single child with a matching attribute 
//set allowPartial to match partial matches 
//e.g. <img src="http://www.google.com> [findChildWithAttribute:@"src" matchingName:"google.com" allowPartial:TRUE]
-(SHKHTMLNode*)findChildWithAttribute:(NSString*)attribute matchingName:(NSString*)className allowPartial:(BOOL)partial;

//Finds all children with a matching attribute
-(NSArray*)findChildrenWithAttribute:(NSString*)attribute matchingName:(NSString*)className allowPartial:(BOOL)partial;

//Gets the attribute value matching tha name
-(NSString*)getAttributeNamed:(NSString*)name;

//Find childer with the specified tag name
-(NSArray*)findChildTags:(NSString*)tagName;

//Looks for a tag name e.g. "h3"
-(SHKHTMLNode*)findChildTag:(NSString*)tagName;

//Returns the first child element
-(SHKHTMLNode*)firstChild;

//Returns the plaintext contents of node
-(NSString*)contents;

//Returns the plaintext contents of this node + all children
-(NSString*)allContents;

//Returns the html contents of the node 
-(NSString*)rawContents;

//Returns next sibling in tree
-(SHKHTMLNode*)nextSibling;

//Returns previous sibling in tree
-(SHKHTMLNode*)previousSibling;

//Returns the class name
-(NSString*)className;

//Returns the tag name
-(NSString*)tagName;

//Returns the parent
-(SHKHTMLNode*)parent;

//Returns the first level of children
-(NSArray*)children;

//Returns the node type if know
-(SHKHTMLNodeType)nodetype;


//C functions for minor performance increase in tight loops
NSString * skGetAttributeNamed(xmlNode * node, const char * nameStr);
void skSetAttributeNamed(xmlNode * node, const char * nameStr, const char * value);
SHKHTMLNodeType skNodeType(xmlNode* node);
NSString * skAllNodeContents(xmlNode*node);
NSString * skRawContentsOfNode(xmlNode * node);


@end
