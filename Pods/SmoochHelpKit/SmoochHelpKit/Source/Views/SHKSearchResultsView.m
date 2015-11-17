//
//  SHKSearchResultsView.m
//  Smooch
//
//  Created by Joel Simpson on 2014-04-29.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKSearchResultsView.h"
#import "SHKMessagesButtonView.h"
#import "SHKTableBackgroundView.h"
#import "SHKUtility.h"

@interface SHKSearchResultsView()

@property UIView* backgroundView;

@end

@implementation SHKSearchResultsView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        self.tableView = [[UITableView alloc] initWithFrame:self.bounds style:UITableViewStylePlain];
        [self.tableView setTableFooterView:[UIView new]];
        self.tableView.contentInset = UIEdgeInsetsMake(0, 0, [SHKMessagesButtonView getHeightNeededForButton], 0);
        self.tableView.backgroundColor = [UIColor clearColor];
        self.tableView.separatorColor = [[UIColor blackColor] colorWithAlphaComponent:0.2];
        
        self.backgroundView = [[SHKTableBackgroundView alloc] initWithFrame:self.bounds];
        
        [self addSubview:self.backgroundView];
        [self addSubview:self.tableView];
        
        self.hidden = YES;
    }
    return self;
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    self.tableView.frame = CGRectMake(0, SHKNavBarHeight(), self.bounds.size.width, self.bounds.size.height - SHKNavBarHeight());
    self.backgroundView.frame = self.bounds;
}
@end
