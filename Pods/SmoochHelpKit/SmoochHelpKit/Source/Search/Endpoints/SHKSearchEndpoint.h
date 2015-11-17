//
//  SHKSearchEndpoint.h
//  Smooch
//
//  Created by Mike Spensieri on 2014-10-14.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SHKSearchEndpoint <NSObject>

// Return the URL including the given query in the query params section
// The given query is already HTML-encoded
-(NSString*)urlForQuery:(NSString*)query;

@optional

// Implement one of these
-(NSArray*)deserializeResultsJSON:(id)jsonObject;
-(NSArray*)deserializeResultsData:(NSData*)responseData;

@end
