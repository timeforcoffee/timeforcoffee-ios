//
//  SHKTableCellVendingMachine.m
//  Smooch
//
//  Created by Mike on 2014-05-07.
//  Copyright (c) 2015 Smooch Technologies. All rights reserved.
//

#import "SHKTableCellVendingMachine.h"
#import "SHKSearchResult.h"
#import "SHKLocalization.h"
#import "SHKUtility.h"
#import "SmoochHelpKit+Private.h"

static const int kMaxNumberOfLinesPerCell = 5;
static const int kMinimumHeightForCell = 40;
static const int kCellTextPadding = 15;

@interface SHKTableCellVendingMachine()

@property UILabel* textMeasurementLabel;

@end

@implementation SHKTableCellVendingMachine

-(CGFloat)heightForSearchResult:(SHKSearchResult *)searchResult constrainedToWidth:(CGFloat)width
{
    return [self heightForText:[self titleForSearchResult:searchResult] constrainedToWidth:width];
}

-(CGFloat)heightForError:(NSError *)error constrainedToWidth:(CGFloat)width
{
    return [self heightForText:[self titleForError:error] constrainedToWidth:width];
}

-(CGFloat)heightForText:(NSString*)text constrainedToWidth:(CGFloat)width
{
    UIFont* fontForCell = [self fontForCellTitle];
    if(self.textMeasurementLabel == nil){
        self.textMeasurementLabel = [[UILabel alloc] init];
        self.textMeasurementLabel.font = fontForCell;
        self.textMeasurementLabel.numberOfLines = kMaxNumberOfLinesPerCell;
    }
    
    self.textMeasurementLabel.text = text;
    
    CGSize maxSize = CGSizeMake(width - (2 * kCellTextPadding),
                                kMaxNumberOfLinesPerCell * fontForCell.lineHeight);
    CGSize actualSize = [self.textMeasurementLabel sizeThatFits:maxSize];
    
    return MAX(actualSize.height + 20, kMinimumHeightForCell);
}

-(UITableViewCell*)cellForSearchResult:(SHKSearchResult *)searchResult dequeueFrom:(UITableView *)tableView
{
    UITableViewCell* cell = [self dequeueResultCell:tableView];
    cell.textLabel.text = [self titleForSearchResult:searchResult];
    cell.userInteractionEnabled = searchResult != nil;
    return cell;
}

-(UITableViewCell*)cellForError:(NSError *)error dequeueFrom:(UITableView *)tableView
{
    UITableViewCell* cell = [self dequeueErrorCell:tableView];
    cell.textLabel.text = [self titleForError:error];
    return cell;
}

- (UITableViewCell *)dequeueResultCell:(UITableView *)tableView
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"search_result"];
    if (nil == cell) {
        cell = [self createGenericCellWithReuseIdentifier:@"search_result"];
        cell.textLabel.textColor = [UIColor blackColor];
    }
    
    return cell;
}

- (UITableViewCell *)dequeueErrorCell:(UITableView *)tableView
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"search_result_error"];
    if (nil == cell) {
        cell = [self createGenericCellWithReuseIdentifier:@"search_result_error"];
        cell.textLabel.textColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:1.0];
        cell.userInteractionEnabled = NO;
    }
    return cell;
}

-(UITableViewCell*)createGenericCellWithReuseIdentifier:(NSString*)identifier
{
    UITableViewCell* cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    cell.textLabel.font = [self fontForCellTitle];
    cell.textLabel.numberOfLines = kMaxNumberOfLinesPerCell;
    cell.backgroundColor = [UIColor clearColor];
    
    UIView* selectedView = [[UIView alloc] init];
    selectedView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.15];
    cell.selectedBackgroundView = selectedView;
    
    return cell;
}

-(NSString*)titleForError:(NSError*)error
{
    if (error.code == SHKBadKnowledgeBaseUrlErrorCode) {
        return error.localizedDescription;
    }
    return [SHKLocalization localizedStringForKey:@"Cannot return search results"];
}

-(NSString*)titleForSearchResult:(SHKSearchResult*)searchResult
{
    return searchResult == nil ? [SHKLocalization localizedStringForKey:@"No results found."] : searchResult.title;
}

-(UIFont*)fontForCellTitle
{
    return [UIFont systemFontOfSize:14];
}

@end
