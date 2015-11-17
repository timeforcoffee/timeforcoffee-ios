//
//  SHKHomeViewController.h
//  Smooch
//
//  Created by Michael Spensieri on 11/12/13.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SHKBaseViewController.h"

@class SHKSearchController;

extern NSString* const SHKSearchBarTextDidBeginEditing;

@interface SHKHomeViewController : SHKBaseViewController <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>

-(instancetype)initWithSearchController:(SHKSearchController*)searchController;
-(void) showBadUrlError;
-(void)keyboardShown:(NSNotification*)notification;

@end
