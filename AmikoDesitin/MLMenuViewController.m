/*
 
 Copyright (c) 2014 Max Lungarella <cybrmx@gmail.com>
 
 Created on 14/02/2014.
 
 This file is part of AmiKoDesitin.
 
 AmiKoDesitin is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program. If not, see <http://www.gnu.org/licenses/>.
 
 ------------------------------------------------------------------------ */

#import "MLMenuViewController.h"

#import "MLConstants.h"
#import "MLCustomURLConnection.h"
#import "MLAlertView.h"
#import "SWRevealViewController.h"
#import "PatientViewController.h"

#import "MLAppDelegate.h"
#import "UpdateManager.h"

@interface MLMenuViewController ()

@end

@implementation MLMenuViewController
{
    NSArray *options;
    MLViewController *mParentViewController;
    UIActionSheet *mMenuActionSheet;
}

- (instancetype) initWithNibName:(NSString *)nibNameOrNil
                          bundle:(NSBundle *)nibBundleOrNil
                          parent:(MLViewController *)parentViewController
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
 
    mParentViewController = parentViewController;
    
    if (self) {
        // Do stuff...
    }
    
    return self;
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

//- (UIStatusBarStyle)preferredStatusBarStyle
//{
//    return UIStatusBarStyleDefault;
//}

// TODO: Implement "viewWillTransitionToSize:withTransitionCoordinator:" instead
- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                 duration:(NSTimeInterval)duration
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
    
    [mMenuActionSheet showInView:[UIApplication sharedApplication].keyWindow];
}

- (void) viewDidLoad
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
    
    [super viewDidLoad];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
    
        // SWRevealViewController extends UIViewController!
        SWRevealViewController *revealController = [self revealViewController];
       
        /*
        UIBarButtonItem *revealButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:NAVIGATION_ICON_LEFT]
                                                                         style:UIBarButtonItemStyleBordered
                                                                        target:revealController
                                                                        action:@selector(revealToggle:)];
        self.navigationItem.leftBarButtonItem = revealButtonItem;
        */
        
        // PanGestureRecognizer goes here
        [self.navigationController.navigationBar addGestureRecognizer:revealController.panGestureRecognizer];
        [self.view addGestureRecognizer:revealController.panGestureRecognizer];
    
        // Single tap gesture recognizer goes here
        UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                    action:@selector(handleSingleTap:)];
        singleTap.numberOfTapsRequired = 1;
        singleTap.delegate = self;
        [self.view addGestureRecognizer:singleTap];
        
        [self.navigationController.navigationBar setHidden:YES];
    }    
}

- (void) handleSingleTap:(UITapGestureRecognizer*)gesture
{
    SWRevealViewController *revealController = [self revealViewController];
    [revealController revealToggle:self];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL) gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

#pragma mark - UIActionSheetDelegate

// TODO: Use UIAlertController with a preferredStyle of UIAlertControllerStyleActionSheet instead
- (void) actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
#ifdef DEBUG
    NSLog(@"%s %d, sheet: %@ sheet.tag: %ld, buttonIndex: %ld", __FUNCTION__, __LINE__,
          sheet,
          sheet.tag,
          (long)buttonIndex);
#endif
    if (sheet.tag != 1)
        return;
    
    switch (buttonIndex) {
        case 0:
            [self sendFeedback:NSLocalizedString(@"Feedback", "Button")];
            break;

        case 1:
            [self shareApp:NSLocalizedString(@"Share", "Button")];
            break;

        case 2:
            [self rateApp:NSLocalizedString(@"Rate", "Button")];
            break;

        case 3:
            [self showReport:NSLocalizedString(@"Report", "Button")];
            break;

        case 4:
            [self startUpdate:NSLocalizedString(@"Update", "Button")];
            break;

        case 5:
            [self showPatients:nil];
            break;

        case 6:
            [self showDoctor:nil];
            break;

        default:
            break;
    }
}

- (void) showMenu
{
    // TODO: replace deprecated UIActionSheet with UIAlertController
    mMenuActionSheet = [[UIActionSheet alloc] initWithTitle:@"Select menu option"
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                     destructiveButtonTitle:nil
                                          otherButtonTitles:
                        NSLocalizedString(@"Feedback", "Button"),
                        NSLocalizedString(@"Share",    "Button"),
                        NSLocalizedString(@"Rate",     "Button"),
                        NSLocalizedString(@"Report",   "Button"),
                        NSLocalizedString(@"Update",   "Button"),
                        NSLocalizedString(@"Patients", "Button"),
                        NSLocalizedString(@"Doctor Signature",   "Button"),
                        nil];
    mMenuActionSheet.tag = 1;
    
    [mMenuActionSheet setActionSheetStyle:UIActionSheetStyleBlackTranslucent];
    
    if (mParentViewController)
        [mMenuActionSheet showInView:[mParentViewController view]];
}

- (void) sendEmailTo:(NSString *)recipient withSubject:(NSString *)subject andBody:(NSString *)body
{
    // Check if device is configured to send email
    if ([MFMailComposeViewController canSendMail]) {
        // Init mail view controller
        MFMailComposeViewController *mailer = [MFMailComposeViewController new];
        mailer.mailComposeDelegate = self;
        
        // Subject
        [mailer setSubject:subject];
        // Recipient
        if (![recipient isEqualToString:@""]) {
            NSArray *toRecipients = [NSArray arrayWithObjects:recipient, nil];
            [mailer setToRecipients:toRecipients];
        }
        // Attach screenshot...
        // UIImage *screenShot = [UIImage imageNamed:@"Default.png"];
        UIGraphicsBeginImageContextWithOptions(mParentViewController.view.bounds.size, NO, [UIScreen mainScreen].scale);
        [mParentViewController.view drawViewHierarchyInRect:mParentViewController.view.bounds afterScreenUpdates:YES];
        UIImage *screenShot = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        NSData *imageData = UIImagePNGRepresentation(screenShot);
        
        [mailer addAttachmentData:imageData mimeType:@"image/png" fileName:@"Images"];
        if (![body isEqualToString:@""]) {
            [mailer setMessageBody:body isHTML:YES];
        }
        // It's important to use the presenting root view controller...
        UIViewController *presentingController = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
        [presentingController presentViewController:mailer animated:YES completion:nil];
    }
    else {
        MLAlertView *alert =
            [[MLAlertView alloc] initWithTitle:@"Failure"
                                       message:@"Your device is not configured to send emails."
                                        button:@"OK"];
        [alert show];
    }
}

#pragma mark - Actions

- (IBAction) sendFeedback:(id)sender
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
    
    [self sendEmailTo:@"zdavatz@ywesee.com"
          withSubject:[NSString stringWithFormat:@"%@ Feedback", APP_NAME]
              andBody:@""];
}

- (IBAction) shareApp:(id)sender
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
    
    NSString* subject = [NSString stringWithFormat:@"%@", APP_NAME];
    NSString* body = nil;
    if ([APP_NAME isEqualToString:@"iAmiKo"] || [APP_NAME isEqualToString:@"AmiKoDesitin"]) {
        body = [NSString stringWithFormat:@"%@: Schweizer Arzneimittelkompendium<br /><br />"
                "Get it now: <a href=https://itunes.apple.com/us/app/amiko/id%@?mt=8>https://itunes.apple.com/us/app/amiko/id%@?mt=8</a>"
                "<br /><br />Enjoy!<br />", APP_NAME, APP_ID, APP_ID];
    }
    else if ([APP_NAME isEqualToString:@"iCoMed"] || [APP_NAME isEqualToString:@"CoMedDesitin"]) {
        body = [NSString stringWithFormat:@"%@: Compendium des Médicaments Suisse<br /><br />"
                "Get it now: <a href=https://itunes.apple.com/us/app/amiko/id%@?mt=8>https://itunes.apple.com/us/app/amiko/id%@?mt=8</a>"
                "<br /><br />Enjoy!<br />", APP_NAME, APP_ID, APP_ID];
    }
    
    [self sendEmailTo:@"" withSubject:subject andBody:body];
}

- (IBAction) rateApp:(id)sender
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
    
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"itms-apps://itunes.apple.com/app/id%@?mt=8", APP_ID]]];
}

- (IBAction) showDoctor:(id)sender
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
    //MLAppDelegate *appDel = (MLAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    if (mParentViewController)
        [mParentViewController switchToDoctorEditView];
}

- (IBAction) showPatients:(id)sender
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
    
    MLAppDelegate *appDel = (MLAppDelegate *)[[UIApplication sharedApplication] delegate];
    appDel.editMode = EDIT_MODE_PATIENTS;

    if (mParentViewController)
        [mParentViewController switchToPatientEditView: YES];
}

- (IBAction) showReport:(id)sender
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
    
    if (mParentViewController)
        [mParentViewController showReport:self];
}

- (IBAction) startUpdate:(id)sender
{
    UpdateManager *um = [UpdateManager sharedInstance];
    [um resetProgressBar];

    [um addLanguageFile:@"amiko_report" extension:@"html"];
    [um addLanguageFile:@"drug_interactions_csv" extension:@"zip"];
    [um addLanguageFile:@"amiko_frequency" extension:@"db.zip"];
    [um addLanguageFile:@"amiko_db_full_idx" extension:@"zip"];

    [um startProgressBar];
}

#pragma mark - MFMailComposeViewControllerDelegate

- (void) mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    UIViewController *presentingController = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    [presentingController dismissViewControllerAnimated:YES completion:nil];

    NSString* message = nil;
    switch (result) {
        case MFMailComposeResultCancelled:
            message = @"No mail sent at user request.";
            break;
        case MFMailComposeResultSaved:
            message = @"Draft saved";
            break;
        case MFMailComposeResultSent:
            message = @"Mail sent";
            break;
        case MFMailComposeResultFailed:
            message = @"Error";
    }
#ifdef DEBUG
    NSLog(@"%s %@", __PRETTY_FUNCTION__, message);
#endif
}

- (void) didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
