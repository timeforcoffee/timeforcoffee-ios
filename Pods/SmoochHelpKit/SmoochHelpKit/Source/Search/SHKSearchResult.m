//
//  SHKSearchResult.m
//  Smooch
//
//  Created by Joel Simpson on 2014-04-29.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKSearchResult.h"
#import "SHKUtility.h"

@implementation SHKSearchResult

-(instancetype)initWithTitle:(NSString *)title url:(NSString *)url
{
    self = [super init];
    if (self) {
        self.title = title;
        self.htmlURL = url;
    }
    return self;
}

-(instancetype)initWithDictionary:(NSDictionary*)jsonResult
{
    self = [super init];
    if (self) {
        self.title = [jsonResult valueForKey:@"name"];
        if (!self.title) {
            self.title = [jsonResult valueForKey:@"title"];
        }
        
        self.htmlURL = [jsonResult valueForKey:@"html_url"];
        if (!self.htmlURL || [self.htmlURL length] == 0) {
            // Need to infer the url of the article to display
            self.htmlURL = [self convertURLToHtmlURL:[jsonResult valueForKey:@"url"]];
        }
        
        self.sectionId = jsonResult[@"section_id"];
        
        //Grab forum_id incase the zendesk is legacy.
        if(!self.sectionId){
            self.sectionId = jsonResult[@"forum_id"];
        }
    }
    return self;
}

// Converts url of type:
//    https://prezi.zendesk.com/api/v2/topics/22140113.json
// to:
//    https://prezi.zendesk.com/entries/22140113
-(NSString*)convertURLToHtmlURL:(NSString*) strUrl
{
    NSURL* url = [NSURL URLWithString:strUrl];
    
    // Get "22140113.json"
    NSString* json_entry = [url lastPathComponent];
    
    // Get "22140113"
    NSString* entry = [[json_entry componentsSeparatedByString:@"."] firstObject];
    
    return [NSString stringWithFormat:@"https://%@/entries/%@", [url host], entry];
}

@end
