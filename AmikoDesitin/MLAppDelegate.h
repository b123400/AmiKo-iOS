/*
 
 Copyright (c) 2013 Max Lungarella <cybrmx@gmail.com>
 
 Created on 24/06/2013.
 
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

#import <UIKit/UIKit.h>

//#define CONTACTS_LIST_FULL_WIDTH
//#define PATIENT_DB_LIST_FULL_WIDTH

typedef NS_ENUM(NSInteger, EditMode) {
    EDIT_MODE_UNDEFINED,
    EDIT_MODE_PATIENTS,
    EDIT_MODE_PRESCRIPTION
};

@class SWRevealViewController;

@interface MLAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) IBOutlet UIWindow *window;
@property (retain, nonatomic) UINavigationController *navController;
@property (strong, nonatomic) SWRevealViewController *revealViewController;
@property EditMode editMode;

- (void) showPrescriptionId:(NSString *)uniqueId :(NSString *)fileName;
- (void) switchRigthToPatientDbList;

@end
