/*
 
 Copyright (c) 2015 Max Lungarella <cybrmx@gmail.com>
 
 Created on 27/10/2015.
 
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

#import "MLUtility.h"
#import "MLConstants.h"

// Issue #106
#define BUNDLE_VERSION_KEY      @"savedBundleVersion"

@implementation MLUtility

// return value, indicates that the the app runs for the first time
+ (BOOL) checkAppVersion
{
    BOOL newBundle = false;

    NSDictionary *d = [[NSBundle mainBundle] infoDictionary];
    NSString *bundleVersion = [d objectForKey:@"CFBundleShortVersionString"];

#ifdef DEBUG
    NSLog(@"%@, %@, %@, %@",
          [d objectForKey:@"CFBundleName"],
          [d objectForKey:@"CFBundleExecutable"],
          [d objectForKey:@"CFBundleShortVersionString"],
          [d objectForKey:@"CFBundleVersion"]);
#endif
    NSString *bundleIdentifier = [d objectForKey:@"CFBundleIdentifier"];
//    NSLog(@"bundle identifier <%@>, display name <%@>",
//          bundleIdentifier,
//          [d objectForKey:@"CFBundleDisplayName"]);
//    NSLog(@"documents dir:\n\t%@", [MLUtility documentsDirectory]);
    NSLog(@"=== Defaults file:\n\t%@/Preferences/%@.plist",
          NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject,
          bundleIdentifier);

#ifdef DEBUG
    // Retrieve bundle root path, e.g. /var/containers/Bundle/Application/<GUID>/<AppName>.app
    NSString *bundleRoot = [[NSBundle mainBundle] bundlePath];
    // Handle to file manager, initialize
    NSFileManager *manager = [NSFileManager defaultManager];

    NSDictionary *attrs = [manager attributesOfItemAtPath:bundleRoot error:nil];
    NSLog(@"=== Bundle path:\n\t%@", bundleRoot);
    NSLog(@"App creation date: %@", [attrs fileCreationDate]);
    NSLog(@"App modification date (unless bundle changed by code): %@", [attrs fileModificationDate]);
    
    NSError *error = nil;
    NSArray *docFolderContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[MLUtility documentsDirectory] error:&error];
    if (error)
        NSLog(@"%s: %@", __FUNCTION__, error.localizedDescription);
    else if ([docFolderContent count] == 0)
        NSLog(@"Documents folder is empty!");
    else
        NSLog(@"=== Documents folder:\n\t%@\nContents:\n%@", [MLUtility documentsDirectory], docFolderContent);
#endif

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *savedBundleVersion = [defaults stringForKey:BUNDLE_VERSION_KEY];
    //NSLog(@"BundleVersion: %@, saved: %@", bundleVersion, savedBundleVersion);
    if (savedBundleVersion.length == 0) {
#ifdef DEBUG
        NSLog(@"=== Fresh installation");
#endif
        newBundle = true;
    }
    else if (![savedBundleVersion isEqualToString:bundleVersion]) {
#ifdef DEBUG
        NSLog(@"=== App has been updated");
#endif
        newBundle = true;
    }
    else {
#ifdef DEBUG
        NSLog(@"=== App runs again");
#endif
        newBundle = false;
#ifdef DEBUG_SIMULATE_NEW_VERSION
        [defaults removeObjectForKey:BUNDLE_VERSION_KEY];
#endif
    }
    
    if (newBundle) {
        NSLog(@"=== Store bundle version into defaults");
        [defaults setObject:bundleVersion forKey:BUNDLE_VERSION_KEY];
        [defaults synchronize];  // This seems to cause problems here
        //NSLog(@"%s %d standardUserDefaults: %@", __FUNCTION__, __LINE__, [defaults dictionaryRepresentation]);
    }

#ifdef DEBUG
    // e.g /var/mobile/Applications/<GUID>
    NSString *rootPath = [bundleRoot substringToIndex:[bundleRoot rangeOfString:@"/" options:NSBackwardsSearch].location];
    attrs = [manager attributesOfItemAtPath:rootPath error:nil];
    NSLog(@"=== Bundle root:\n\t%@", rootPath);
    NSLog(@"App installation date (or first reinstalled after deletion): %@", [attrs fileCreationDate]);
#endif

    return newBundle;
}

+ (NSNumber*) timeIntervalInSecondsSince1970:(NSDate *)date
{
    // Result in seconds
    NSNumber* timeInterval = [NSNumber numberWithDouble:[date timeIntervalSince1970]];
    return timeInterval;
}

+ (void) updateDBCheckedTimestamp
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *keyDBLastUpdate = [MLConstants databaseUpdateKey];
    [defaults setValue:[NSDate date] forKey:keyDBLastUpdate];
    [defaults synchronize];
}

+ (double) timeIntervalSinceLastDBSync
{
    double timeInterval = 0.0;
    
    NSDate *lastUpdated = [[NSUserDefaults standardUserDefaults] objectForKey:[MLConstants databaseUpdateKey]];
    if (lastUpdated)
        timeInterval = [[NSDate date] timeIntervalSinceDate:lastUpdated];

#ifdef DEBUG_ISSUE_106
    if (lastUpdated) {
        NSLog(@"DB last updated : %@, %.1f s ago", lastUpdated, timeInterval);

        NSString *title = [NSString stringWithFormat:@"Last DB update %.0fs ago", timeInterval];
        NSString *message = [NSDateFormatter localizedStringFromDate:lastUpdated
                                                 dateStyle:NSDateFormatterShortStyle
                                                 timeStyle:NSDateFormatterFullStyle];
        NSLog(@"%@ %@", title, message);
    }
    else {
        NSLog(@"timestamp not found");
        //NSLog(@"%s %d timestamp not found in standardUserDefaults: %@", __FUNCTION__, __LINE__, [[NSUserDefaults standardUserDefaults] dictionaryRepresentation]);
    }
#endif

    return timeInterval;
}

+ (NSString *) currentTime
{
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm.ss";
    [dateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
    return [dateFormatter stringFromDate:[NSDate date]];
}

+ (NSString *) prettyTime
{
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.dateFormat = @"dd.MM.yyyy (HH:mm:ss)";
    [dateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
    return [dateFormatter stringFromDate:[NSDate date]];
}

+ (NSString*) encodeStringToBase64:(NSString*)string
{
    NSData *plainData = [string dataUsingEncoding:NSUTF8StringEncoding];
    return [plainData base64EncodedStringWithOptions:0];
}

// Alternatively the implementation could also use NSHomeDirectory()
+ (NSString *) documentsDirectory
{
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_8_0
    // if you need to support iOS 7 or earlier
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    //NSLog(@"first:%@", [paths firstObject]);
    //NSLog(@"last:%@", [paths lastObject]);
    return [paths lastObject];
#else
    // iOS 8 and newer, this is the recommended method
    NSArray *paths = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                        inDomains:NSUserDomainMask];
    NSURL *url = [paths lastObject];
    //NSLog(@"abs.: <%@>", url.absoluteString);   // "file:///Users/... ...Documents/"
    //NSLog(@"path: <%@>", url.path);             // "/Users/...  .../Documents"
    return url.path;
#endif
}

// Create the directory if it doesn't exist
+ (NSString *) amkBaseDirectory
{
    NSString *amk = [[MLUtility documentsDirectory] stringByAppendingPathComponent:@"amk"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:amk])
    {
        NSError *error;
        [[NSFileManager defaultManager] createDirectoryAtPath:amk
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
        if (error) {
            NSLog(@"error creating directory: %@", error.localizedDescription);
            amk = nil;
        }
    }
    return amk;
}

+ (NSString *) amkDirectory
{
    NSString *amk = [MLUtility amkBaseDirectory];

    // If the current patient is defined in the defaults,
    // return his/her subdirectory
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *patientId = [defaults stringForKey:@"currentPatient"];
    if (patientId)
        return [MLUtility amkDirectoryForPatient:patientId];
    
    return amk;
}

+ (NSString *) amkDirectoryForPatient:(NSString*)uid
{
    NSString *amk = [MLUtility amkBaseDirectory];
    NSString *patientAmk = [amk stringByAppendingPathComponent:uid];
    if (![[NSFileManager defaultManager] fileExistsAtPath:patientAmk])
    {
        NSError *error;
        [[NSFileManager defaultManager] createDirectoryAtPath:patientAmk
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
        if (error) {
            NSLog(@"error creating directory: %@", error.localizedDescription);
            patientAmk = nil;
        }
#ifdef DEBUG
        else
            NSLog(@"Created patient directory: %@", patientAmk);
#endif
    }
    
    return patientAmk;
}

+ (BOOL) emailValidator:(NSString *)msg
{
    NSString *regex = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}";
    return [[NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex] evaluateWithObject:[msg stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
}

+ (NSString *) getColorCss
{

    NSString *colorSchemeFilename = @"color-scheme-light";

#ifdef DEBUG
    NSLog(@"%@, %ld",
          [UITraitCollection currentTraitCollection],
          [UITraitCollection currentTraitCollection].userInterfaceStyle);
#endif
    UIUserInterfaceStyle osMode = [UITraitCollection currentTraitCollection].userInterfaceStyle;
    if (@available(iOS 13, *))
        if (osMode == UIUserInterfaceStyleDark)
            colorSchemeFilename = @"color-scheme-dark";
    
    NSString *colorCssPath = [[NSBundle mainBundle] pathForResource:colorSchemeFilename ofType:@"css"];
    NSString *colorCss = [NSString stringWithContentsOfFile:colorCssPath encoding:NSUTF8StringEncoding error:nil];
    return colorCss;
}

@end
