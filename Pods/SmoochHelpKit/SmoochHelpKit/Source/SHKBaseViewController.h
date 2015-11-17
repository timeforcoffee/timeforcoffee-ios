//
//  SHKBaseViewController.h
//  Smooch
//
//  Created by Michael Spensieri on 11/25/13.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SHKMessagesButtonView.h"

@class SHKSearchBarView;

@interface SHKBaseViewController : UIViewController < UISearchBarDelegate, SHKMessagesButtonPositioningDelegate >

-(void)setSearchText:(NSString *)searchText;

-(void)onSmoochBecameInactive;
-(void)onSmoochBecameActive;

@property SHKSearchBarView* searchBar;

@end
