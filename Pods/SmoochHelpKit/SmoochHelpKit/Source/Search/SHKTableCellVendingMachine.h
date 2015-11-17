//
//  SHKTableCellVendingMachine.h
//  Smooch
//
//  Created by Mike on 2014-05-07.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
@class SHKSearchResult;

@interface SHKTableCellVendingMachine : NSObject

-(CGFloat)heightForSearchResult:(SHKSearchResult *)searchResult constrainedToWidth:(CGFloat)width;
-(CGFloat)heightForError:(NSError*)error constrainedToWidth:(CGFloat)width;

-(UITableViewCell*)cellForSearchResult:(SHKSearchResult*)searchResult dequeueFrom:(UITableView*)tableView;
-(UITableViewCell*)cellForError:(NSError*)error dequeueFrom:(UITableView*)tableView;

@end
