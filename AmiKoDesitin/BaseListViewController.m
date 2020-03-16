//
//  BaseListViewController.m
//  AmikoDesitin
//
//  Created by Alex Bettarini on 13 Feb 2018
//  Copyright © 2018 Ywesee GmbH. All rights reserved.
//

#import "BaseListViewController.h"
#import "MLAppDelegate.h"
#import "SWRevealViewController.h"

@interface BaseListViewController ()

- (BOOL) stringIsNilOrEmpty:(NSString*)str;

@end

#pragma mark -

@implementation BaseListViewController

@synthesize theSearchBar;
@synthesize mArray;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    mSearchFiltered = FALSE;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (id) getItemAtRow:(NSInteger)row
{
    if (mSearchFiltered)
        return mFilteredArray[row];
    
    if (mArray)
        return mArray[row];
    
    return nil;
}

// This is supposed to be overloaded by subclasses

- (NSString *) getTextAtRow:(NSInteger)row
{
#ifdef DEBUG
    NSLog(@"%s This shouldn't get called", __FUNCTION__);
#endif
    return @"";
}

- (BOOL) stringIsNilOrEmpty:(NSString*)str
{
    return !(str && str.length);
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    if ([self stringIsNilOrEmpty:searchText]) {
        mSearchFiltered = FALSE;
    }
    else {
        mSearchFiltered = TRUE;
        NSPredicate *p1 = [NSPredicate predicateWithFormat:@"familyName BEGINSWITH[cd] %@", searchText];
        NSPredicate *p2 = [NSPredicate predicateWithFormat:@"givenName BEGINSWITH[cd] %@", searchText];
        NSPredicate *p3 = [NSPredicate predicateWithFormat:@"postalAddress BEGINSWITH[cd] %@", searchText];
        NSPredicate *p4 = [NSPredicate predicateWithFormat:@"zipCode BEGINSWITH[cd] %@", searchText];
        
        NSPredicate *predicate = [NSCompoundPredicate orPredicateWithSubpredicates: [NSArray arrayWithObjects: p1, p2, p3, p4, nil]];
        
        mFilteredArray = [mArray filteredArrayUsingPredicate:predicate];
    }

    [mTableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger) tableView: (UITableView *)tableView
  numberOfRowsInSection: (NSInteger)section
{
    if (mSearchFiltered)
        return [mFilteredArray count];
    
    return [mArray count];
}

- (UITableViewCell *) tableView: (UITableView *)tableView
          cellForRowAtIndexPath: (NSIndexPath *)indexPath
{    
    //static NSString *tableIdentifier = @"genericListTableItem";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:tableIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:tableIdentifier];
        cell.textLabel.textAlignment = NSTextAlignmentLeft;
        //cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.textColor = textColor;
    }
    NSString *cellStr = [self getTextAtRow:indexPath.row];
    cell.textLabel.text = cellStr;
    return cell;
}

#pragma mark - UITableViewDelegate

- (void) tableView: (UITableView *)tableView didSelectRowAtIndexPath: (NSIndexPath *)indexPath
{
    // Show front view
    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName
                                                        object:[self getItemAtRow:indexPath.row]];    
    mSearchFiltered = FALSE;
}

@end
