//
//  PatientDbListViewController.m
//  AmikoDesitin
//
//  Created by Alex Bettarini on 13 Feb 2018
//  Copyright © 2018 Ywesee GmbH. All rights reserved.
//

#import "PatientDbListViewController.h"
#import "PatientDBAdapter.h"
#import "SWRevealViewController.h"

#import "MLViewController.h"
#import "PatientViewController.h"

#import "MLAppDelegate.h"
#import "MLUtility.h"

@interface PatientDbListViewController ()

@end

@implementation PatientDbListViewController
{
    PatientDBAdapter *mPatientDb;
}

+ (PatientDbListViewController *)sharedInstance
{
    __strong static id sharedObject = nil;

    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        sharedObject = [self new];
    });
    return sharedObject;
}

// Called once per instance
- (void)viewDidLoad
{
#ifdef DEBUG
    NSLog(@"%s %p", __FUNCTION__, self);
#endif
    [super viewDidLoad];

    notificationName = @"PatientSelectedNotification";
    tableIdentifier = @"patientDbListTableItem";
    textColor = [UIColor labelColor];
    // TODO: (TBC) make sure the right view is back to the iOS Contacts list, for the sake of the swiping action
}

// Called every time the instance is displayed
- (void)viewDidAppear:(BOOL)animated
{
#ifdef DEBUG
    NSLog(@"%s %p", __FUNCTION__, self);
#endif
    
    mSearchFiltered = FALSE;
    
    // Retrieves contacts from address DB
    // Open patient DB
    mPatientDb = [PatientDBAdapter new];
    if (![mPatientDb openDatabase:@"patient_db"]) {
        NSLog(@"Could not open patient DB!");
        mPatientDb = nil;
    }
    else {
        self.mArray = [mPatientDb getAllPatients];
        [mTableView reloadData];
    }    

    [self.theSearchBar becomeFirstResponder];
    [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleDefault;
}

#pragma mark -

- (void) removeItem:(NSUInteger)rowIndex
{
    Patient *pat = nil;
    if (mSearchFiltered) {
        pat = mFilteredArray[rowIndex];
    }
    else {
        pat = self.mArray[rowIndex];
    }
    
    // Remove the amk subdirectory for this patient
    NSString *amkDir = [MLUtility amkDirectory];
#ifdef DEBUG
    NSLog(@"remove patient %@", amkDir);
#endif
    NSError *error;
    BOOL success = [[NSFileManager defaultManager] removeItemAtPath:amkDir error:&error];
    if (!success || error)
        NSLog(@"Error removing file at path: %@", error.localizedDescription);

#ifdef DEBUG
    NSLog(@"patients before deleting: %ld", [mPatientDb getNumPatients]);
#endif
    
    // Finally remove the entry from the list
    [mPatientDb deleteEntry:pat];

#ifdef DEBUG
    NSLog(@"patients after deleting: %ld", [mPatientDb getNumPatients]);
#endif

    // Clear the current user
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:@"currentPatient"];
    [defaults synchronize];
    
#ifdef DEBUG_ISSUE_86
    NSLog(@"%s %d cleared currentPatient", __FUNCTION__, __LINE__);
#endif
    
    // (Instead of removing one item from a NSMutableArray) reassign the whole NSArray
    self.mArray = [mPatientDb getAllPatients];

    mSearchFiltered = FALSE;
    [mTableView reloadData];
    
    // TODO: the patient edit view needs to go blank.
}

#pragma mark - Overloaded

- (NSString *) getTextAtRow:(NSInteger)row
{
#ifdef DEBUG
    //NSLog(@"%s", __FUNCTION__);
#endif
    Patient *p = [self getItemAtRow:row];
    NSString *cellStr = [NSString stringWithFormat:@"%@ %@", p.familyName, p.givenName];
    return cellStr;
}

#pragma mark - UIGestureRecognizerDelegate

- (IBAction) handleLongPress:(UILongPressGestureRecognizer *)gesture
{
    CGPoint p = [gesture locationInView:mTableView];
    NSIndexPath *indexPath = [mTableView indexPathForRowAtPoint:p];
    
    if (indexPath == nil) {
        NSLog(@"long press on table view but not on a row");
        return;
    }

    if (gesture.state != UIGestureRecognizerStateBegan) {
#ifdef DEBUG
        //NSLog(@"gestureRecognizer.state = %ld", gesture.state);
#endif
        return;
    }
    
    //NSLog(@"long press on table view at row %ld", indexPath.row);
    MLAppDelegate *appDel = (MLAppDelegate *)[[UIApplication sharedApplication] delegate];

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *actionDelete = [UIAlertAction actionWithTitle:NSLocalizedString(@"Delete", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
                                                             [alertController dismissViewControllerAnimated:YES completion:nil];
                                                             
                                                              [self removeItem:indexPath.row];
                                                         }];
    [alertController addAction:actionDelete];

    if (appDel.editMode == EDIT_MODE_PRESCRIPTION) {
        UIAlertAction *actionEdit = [UIAlertAction actionWithTitle:NSLocalizedString(@"Edit", nil)
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction *action) {
                                                                 [alertController dismissViewControllerAnimated:YES completion:nil];
                                                                 
                                                                 // Make sure front is PatientViewController
                                                                 UIViewController *nc_front = self.revealViewController.frontViewController;
                                                                 UIViewController *vc_front = [nc_front.childViewControllers firstObject];
                                                                 if (![vc_front isKindOfClass:[PatientViewController class]]) {
                                                                     UIViewController *nc_rear = self.revealViewController.rearViewController;
                                                                     MLViewController *vc_rear = [nc_rear.childViewControllers firstObject];
                                                                     [vc_rear switchFrontToPatientEditView];
                                                                 }

                                                                 // Update the pointers to our controllers
                                                                 nc_front = self.revealViewController.frontViewController;
                                                                 vc_front = [nc_front.childViewControllers firstObject];
                                                                 //NSLog(@"nc_front: %@", [nc_front class]); // UINavigationController
                                                                 //NSLog(@"vc_front: %@", [vc_front class]); // PatientViewController
                                                                 if ([vc_front isKindOfClass:[PatientViewController class]]) {

                                                                     // Make sure viewDidLoad has run once before setting the patient
                                                                     [vc_front view];

                                                                     PatientViewController *pvc = (PatientViewController *)vc_front;
                                                                     [pvc resetAllFields];
                                                                     
                                                                     Patient *pat = nil;
                                                                     if (mSearchFiltered)
                                                                         pat = mFilteredArray[indexPath.row];
                                                                     else
                                                                         pat = self.mArray[indexPath.row];
                                                                     
                                                                     [pvc setAllFields:pat];

                                                                     // Finally show it
                                                                     [self.revealViewController rightRevealToggle:self];
                                                                 }
                                                                 
                                                             }];
        [alertController addAction:actionEdit];
    }
    else if ((appDel.editMode == EDIT_MODE_PATIENTS) &&
             ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone))
    {
        UIAlertAction *actionCancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction *action) {
                                                                 [alertController dismissViewControllerAnimated:YES completion:nil];
                                                             }];
        [alertController addAction:actionCancel];
    }

    [alertController setModalPresentationStyle:UIModalPresentationPopover];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        UITableViewCell *cell = [mTableView cellForRowAtIndexPath:indexPath];
        alertController.popoverPresentationController.sourceView = cell.contentView;
    }
    
    [self presentViewController:alertController animated:YES completion:nil]; // It returns immediately
}

@end
