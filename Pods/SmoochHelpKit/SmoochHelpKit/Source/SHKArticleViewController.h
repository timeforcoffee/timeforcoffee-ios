//
//  SHKArticleViewController.h
//  Smooch
//
//  Created by Michael Spensieri on 11/25/13.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SHKBaseViewController.h"

@interface SHKArticleViewController : SHKBaseViewController

-(id)initWithUrlString:(NSString*)urlString;

@property BOOL showsSearchBar;

@end
