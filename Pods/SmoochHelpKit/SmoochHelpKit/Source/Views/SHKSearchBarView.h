//
//  SHKSearchBarView.h
//  Smooch
//
//  Created by Dominic Jodoin on 1/20/2014.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SHKSearchBarView : UISearchBar

-(instancetype)initWithFrame:(CGRect)frame text:(NSString*)text andPlaceholder:(NSString*)placeholder;

-(void)showSpinner;
-(void)hideSpinner;

@end
