//
//  MLPersistenceManager.m
//  AmiKoDesitin
//
//  Created by b123400 on 2020/03/14.
//  Copyright © 2020 Ywesee GmbH. All rights reserved.
//

#import "MLPersistenceManager.h"
#import "MLConstants.h"
#import "MLUtility.h"
#import "Operator.h"
#import "Prescription.h"
#import "PatientModel+CoreDataClass.h"
#import "LegacyPatientDBAdapter.h"

#define KEY_PERSISTENCE_SOURCE @"KEY_PERSISTENCE_SOURCE"

@interface MLPersistenceManager ()

- (void)moveFile:(NSURL *)url toURL:(NSURL *)targetUrl overwriteIfExisting:(BOOL)overwrite;
- (void)mergeFolderRecursively:(NSURL *)fromURL to:(NSURL *)toURL;

- (NSURL *)amkBaseDirectory;
- (PatientModel *)getPatientModelWithUniqueID:(NSString *)uniqueID;

@property NSPersistentCloudKitContainer *coreDataContainer;

@end

@implementation MLPersistenceManager

+ (instancetype)shared {
    __strong static id sharedObject = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedObject = [[MLPersistenceManager alloc] init];
    });
    
    return sharedObject;
}

- (instancetype)init {
    if (self = [super init]) {
        // TODO: take care of updated icloud status when app is active
        // https://developer.apple.com/library/archive/documentation/General/Conceptual/iCloudDesignGuide/Chapters/iCloudFundametals.html#//apple_ref/doc/uid/TP40012094-CH6-SW6
        [self setCurrentSource:MLPersistenceSourceLocal];
        [self setCurrentSource:MLPersistenceSourceICloud];
        
        self.coreDataContainer = [[NSPersistentCloudKitContainer alloc] initWithName:@"Model"];

        NSPersistentStoreDescription *description = [[self.coreDataContainer persistentStoreDescriptions] firstObject];
        NSPersistentCloudKitContainerOptions *options = [[NSPersistentCloudKitContainerOptions alloc] initWithContainerIdentifier:[MLConstants iCloudContainerIdentifier]];
        description.cloudKitContainerOptions = options;
        
        [self.coreDataContainer loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription * _Nonnull desc, NSError * _Nullable error) {
            if (error != nil) {
                NSLog(@"Coredata error %@", error);
                return;
            }
            [self.coreDataContainer viewContext].automaticallyMergesChangesFromParent = YES;
            [self migratePatientSqliteToCoreData];
        }];
    }
    return self;
}

+ (BOOL)supportICloud {
    return [[NSFileManager defaultManager] ubiquityIdentityToken] != nil;
}

- (void)setCurrentSource: (MLPersistenceSource) source {
    if (source == self.currentSource) {
        return;
    }
    if (source == MLPersistenceSourceICloud && ![MLPersistenceManager supportICloud]) {
        return;
    }
    switch (source) {
        case MLPersistenceSourceLocal:
            [self migrateToLocal];
            break;
        case MLPersistenceSourceICloud:
            [self migrateToICloud];
            break;
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:source forKey:KEY_PERSISTENCE_SOURCE];
    [defaults synchronize];
}

- (MLPersistenceSource)currentSource {
    return [[NSUserDefaults standardUserDefaults] integerForKey:KEY_PERSISTENCE_SOURCE];
}

- (void)migrateToLocal {
    if (self.currentSource == MLPersistenceSourceLocal) {
        return;
    }
}

- (NSURL *)iCloudDocumentDirectory {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSURL *rootDir = [manager URLForUbiquityContainerIdentifier:[MLConstants iCloudContainerIdentifier]];
    NSURL *docUrl = [rootDir URLByAppendingPathComponent:@"Documents"];
    if (![manager fileExistsAtPath:[docUrl path]]) {
        [manager createDirectoryAtURL:docUrl
          withIntermediateDirectories:YES
                           attributes:nil
                                error:nil];
    }
    return docUrl;
}

- (NSURL *)documentDirectory {
    if (self.currentSource == MLPersistenceSourceICloud) {
        return [self iCloudDocumentDirectory];
    }
    return [NSURL fileURLWithPath:[MLUtility documentsDirectory]];
}

- (NSManagedObjectContext *)managedViewContext {
    return self.coreDataContainer.viewContext;
}

# pragma mark - Migration Local -> iCloud

- (void)migrateToICloud {
    if (self.currentSource == MLPersistenceSourceICloud) {
        return;
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self doctorDictionary]; // Migrate to file based doctor storage
        NSURL *localDocument = [NSURL fileURLWithPath:[MLUtility documentsDirectory]];
        NSURL *remoteDocument = [self iCloudDocumentDirectory];

        [self moveFile:[localDocument URLByAppendingPathComponent:@"doctor.plist"]
                 toURL:[remoteDocument URLByAppendingPathComponent:@"doctor.plist"]
   overwriteIfExisting:NO];
        [self moveFile:[localDocument URLByAppendingPathComponent:DOC_SIGNATURE_FILENAME]
                      toURL:[remoteDocument URLByAppendingPathComponent:DOC_SIGNATURE_FILENAME]
        overwriteIfExisting:NO];
        [self mergeFolderRecursively:[localDocument URLByAppendingPathComponent:@"amk" isDirectory:YES]
                                  to:[remoteDocument URLByAppendingPathComponent:@"amk" isDirectory:YES]];
    });
}

# pragma mark - Doctor

- (NSURL *)doctorDictionaryURL {
    return [[self documentDirectory] URLByAppendingPathComponent:@"doctor.plist"];
}

- (void)setDoctorDictionary:(NSDictionary *)dict {
    [dict writeToURL:self.doctorDictionaryURL
          atomically:YES];
}

- (NSDictionary *)doctorDictionary {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *doctorDictionary = [defaults dictionaryForKey:@"currentDoctor"];
    if (doctorDictionary != nil) {
        // Migrate to use document file
        [self setDoctorDictionary:doctorDictionary];
        [defaults removeObjectForKey:@"currentDoctor"];
        [defaults synchronize];
    } else {
        doctorDictionary = [NSDictionary dictionaryWithContentsOfURL:self.doctorDictionaryURL];
    }
    return doctorDictionary;
}

- (void)setDoctorSignature:(UIImage *)image {
    NSString *filePath = [[[self documentDirectory] URLByAppendingPathComponent:DOC_SIGNATURE_FILENAME] path];
    [UIImagePNGRepresentation(image) writeToFile:filePath atomically:YES];
}

- (UIImage*)doctorSignature {
    NSString *filePath = [[[self documentDirectory] URLByAppendingPathComponent:DOC_SIGNATURE_FILENAME] path];
    return [[UIImage alloc] initWithContentsOfFile:filePath];
}

# pragma mark - Prescription

- (NSURL *)amkBaseDirectory {
    if (self.currentSource == MLPersistenceSourceICloud) {
        NSURL *url = [[self documentDirectory] URLByAppendingPathComponent:@"amk"];
        [[NSFileManager defaultManager] createDirectoryAtURL:url
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:nil];
        return url;
    }
    return [NSURL fileURLWithPath:[self localAmkBaseDirectory]];
}

- (NSURL *)amkDirectory {
    // If the current patient is defined in the defaults,
    // return his/her subdirectory
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *patientId = [defaults stringForKey:@"currentPatient"];
    if (patientId)
        return [self amkDirectoryForPatient:patientId];
    return [self amkBaseDirectory];
}

- (NSURL *)amkDirectoryForPatient:(NSString*)uid {
    NSURL *amk = [self amkBaseDirectory];
    NSURL *patientAmk = [amk URLByAppendingPathComponent:uid];
    if (![[NSFileManager defaultManager] fileExistsAtPath:[patientAmk path]])
    {
        NSError *error;
        [[NSFileManager defaultManager] createDirectoryAtPath:[patientAmk path]
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
        if (error) {
            NSLog(@"error creating directory: %@", error.localizedDescription);
            patientAmk = nil;
        } else {
            NSLog(@"Created patient directory: %@", patientAmk);
        }
    }
    
    return patientAmk;
}


// Create the directory if it doesn't exist
- (NSString *) localAmkBaseDirectory
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

- (NSURL *)savePrescription:(Prescription *)prescription {
    NSURL *amkDir;
    NSString *uid = [prescription.patient uniqueId];
    if (uid)
        amkDir = [self amkDirectoryForPatient:uid];
    else
        amkDir = [self amkDirectory];
    
    NSError *error;

    prescription.placeDate = [NSString stringWithFormat:@"%@, %@",
                              prescription.doctor.city,
                              [MLUtility prettyTime]];

    NSMutableDictionary *prescriptionDict = [NSMutableDictionary new];
    [prescriptionDict setObject:prescription.hash forKey:KEY_AMK_HASH];
    [prescriptionDict setObject:prescription.placeDate forKey:KEY_AMK_PLACE_DATE];
    [prescriptionDict setObject:[prescription makePatientDictionary] forKey:KEY_AMK_PATIENT];
    [prescriptionDict setObject:[prescription makeOperatorDictionary] forKey:KEY_AMK_OPERATOR];
    [prescriptionDict setObject:[prescription makeMedicationsArray] forKey:KEY_AMK_MEDICATIONS];
    NSData *jsonObject = [NSJSONSerialization dataWithJSONObject:prescriptionDict
                                                         options:NSJSONWritingPrettyPrinted
                                                           error:&error];
    
    NSString *jsonStr = [[NSString alloc] initWithData:jsonObject encoding:NSUTF8StringEncoding];
    NSString *base64Str = [MLUtility encodeStringToBase64:jsonStr];

    // Prescription file name like AmiKo
    NSString *currentTime = [[MLUtility currentTime] stringByReplacingOccurrencesOfString:@":" withString:@""];
    currentTime = [currentTime stringByReplacingOccurrencesOfString:@"." withString:@""];
    NSString *amkFile = [NSString stringWithFormat:@"RZ_%@.amk", currentTime];
    NSURL *amkFileURL = [amkDir URLByAppendingPathComponent:amkFile];
    
    BOOL saved = [base64Str writeToURL:amkFileURL
                            atomically:YES
                              encoding:NSUTF8StringEncoding
                                 error:&error];
    if (saved) {
        return amkFileURL;
    }
    return nil;
}

# pragma mark - Patient

- (NSString *)addPatient:(Patient *)patient {
    NSString *uuidStr = [patient generateUniqueID];
    patient.uniqueId = uuidStr;

    NSManagedObjectContext *context = [[self coreDataContainer] viewContext];
    PatientModel *pm = [NSEntityDescription insertNewObjectForEntityForName:@"Patient"
                                                     inManagedObjectContext:context];

    [pm importFromPatient:patient timestamp: [NSDate new]];
    
    NSError *error = nil;
    [context save:&error];
    if (error != nil) {
        NSLog(@"Cannot create patient %@", error);
    }
    return uuidStr;
}

- (NSString *)upsertPatient:(Patient *)patient {
    NSError *error = nil;
    if (patient.uniqueId.length) {
        PatientModel *p = [self getPatientModelWithUniqueID:patient.uniqueId];
        p.weightKg = patient.weightKg;
        p.heightCm = patient.heightCm;
        p.zipCode = patient.zipCode;
        p.city = patient.city;
        p.country = patient.country;
        p.postalAddress = patient.postalAddress;
        p.phoneNumber = patient.phoneNumber;
        p.emailAddress = patient.emailAddress;
        p.gender = patient.gender;
        [[self.coreDataContainer viewContext] save:&error];
        if (error != nil) {
            NSLog(@"Cannot update patient %@", error);
        }
        return patient.uniqueId;
    } else {
        return [self addPatient:patient];
    }
}

- (BOOL)deletePatient:(Patient *)patient {
    if (!patient.uniqueId.length) {
        return NO;
    }
    PatientModel *pm = [self getPatientModelWithUniqueID:patient.uniqueId];
    if (!pm) {
        return NO;
    }
    NSManagedObjectContext *context = [self.coreDataContainer viewContext];
    [context deleteObject:pm];
    return YES;
}

- (NSArray<Patient *> *)getAllPatients {
    NSError *error = nil;
    NSManagedObjectContext *context = [[self coreDataContainer] viewContext];
    
    NSFetchRequest *req = [PatientModel fetchRequest];
    req.sortDescriptors = @[
        [NSSortDescriptor sortDescriptorWithKey:@"familyName" ascending:YES]
    ];
    
    NSArray<PatientModel*> *pm = [context executeFetchRequest:req error:&error];
    if (error != nil) {
        NSLog(@"Cannot get all patients %@", error);
    }
    return [pm valueForKey:@"toPatient"];
}

- (NSFetchedResultsController *)resultsControllerForAllPatients {
    NSManagedObjectContext *context = [self.coreDataContainer viewContext];
    NSFetchRequest *fetchRequest = [PatientModel fetchRequest];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"familyName" ascending:YES];
    fetchRequest.sortDescriptors = @[sortDescriptor];

    NSFetchedResultsController *controller = [[NSFetchedResultsController alloc]
            initWithFetchRequest:fetchRequest
            managedObjectContext:context
            sectionNameKeyPath:nil
            cacheName:nil];
    return controller;
}

- (PatientModel *)getPatientModelWithUniqueID:(NSString *)uniqueID {
    NSError *error = nil;
    NSManagedObjectContext *context = [[self coreDataContainer] viewContext];
    NSFetchRequest *req = [PatientModel fetchRequest];
    req.predicate = [NSPredicate predicateWithFormat:@"uniqueId == %@", uniqueID];
    req.fetchLimit = 1;
    NSArray<PatientModel *> *patientModels = [context executeFetchRequest:req error:&error];
    return [patientModels firstObject];
}

- (Patient *) getPatientWithUniqueID:(NSString *)uniqueID {
    return [[self getPatientModelWithUniqueID:uniqueID] toPatient];
}

# pragma mark - Migration

- (void)migratePatientSqliteToCoreData {
    NSManagedObjectContext *context = [self.coreDataContainer newBackgroundContext];
    [context performBlock:^{
        LegacyPatientDBAdapter *adapter = [[LegacyPatientDBAdapter alloc] init];
        if (![adapter openDatabase]) {
            return;
        }
        NSArray<Patient *> *patients = [adapter getAllPatients];
        NSMutableArray *dicts = [NSMutableArray arrayWithCapacity:patients.count];
        for (Patient *patient in patients) {
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            if (patient.birthDate != nil) {
                dict[@"birthDate"] = patient.birthDate;
            }
            if (patient.city != nil) {
                dict[@"city"] = patient.city;
            }
            if (patient.country != nil) {
                dict[@"country"] = patient.country;
            }
            if (patient.emailAddress != nil) {
                dict[@"emailAddress"] = patient.emailAddress;
            }
            if (patient.familyName != nil) {
                dict[@"familyName"] = patient.familyName;
            }
            if (patient.gender != nil) {
                dict[@"gender"] = patient.gender;
            }
            if (patient.givenName != nil) {
                dict[@"givenName"] = patient.givenName;
            }
            if (patient.heightCm != 0) {
                dict[@"heightCm"] = @(patient.heightCm);
            }
            if (patient.phoneNumber != nil) {
                dict[@"phoneNumber"] = patient.phoneNumber;
            }
            if (patient.postalAddress != nil) {
                dict[@"postalAddress"] = patient.postalAddress;
            }
            if (patient.uniqueId != nil) {
                dict[@"uniqueId"] = patient.uniqueId;
            }
            if (patient.weightKg != 0) {
                dict[@"weightKg"] = @(patient.weightKg);
            }
            if (patient.zipCode != nil) {
                dict[@"zipCode"] = patient.zipCode;
            }
            dict[@"timestamp"] = [NSDate date];
            [dicts addObject:dict];
        }
        NSBatchInsertRequest *req = [[NSBatchInsertRequest alloc] initWithEntity:[PatientModel entity]
                                                                         objects:dicts];
        NSError *error = nil;
        [context executeRequest:req error:&error];
        if (error != nil) {
            NSLog(@"Cannot migrate %@", error);
            return;
        }
        NSString *dbPath = [adapter dbPath];
        [[NSFileManager defaultManager] removeItemAtPath:dbPath error:nil];
    }];
}

# pragma mark - Utility

- (void)moveFile:(NSURL *)url toURL:(NSURL *)targetUrl overwriteIfExisting:(BOOL)overwrite {
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:[url path]]) {
        return;
    }
    BOOL exist = [manager fileExistsAtPath:[targetUrl path]];
    if (exist && overwrite) {
        [manager replaceItemAtURL:targetUrl
                    withItemAtURL:url
                   backupItemName:[NSString stringWithFormat:@"%@.bak", [url lastPathComponent]]
                          options:NSFileManagerItemReplacementUsingNewMetadataOnly
                 resultingItemURL:nil
                            error:nil];
        [manager removeItemAtURL:url error:nil];
    } else if (!exist) {
        [manager moveItemAtURL:url
                         toURL:targetUrl
                         error:nil];
    }

}

- (void)mergeFolderRecursively:(NSURL *)fromURL to:(NSURL *)toURL {
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    BOOL sourceExist = [manager fileExistsAtPath:[fromURL path] isDirectory:&isDirectory];
    if (!sourceExist || !isDirectory) {
        return;
    }
    isDirectory = NO;
    BOOL destExist = [manager fileExistsAtPath:[toURL path] isDirectory:&isDirectory];
    if (destExist && !isDirectory) {
        // Remote is a file but we need a directory, abort
        return;
    }
    if (!destExist) {
        [manager createDirectoryAtURL:toURL
          withIntermediateDirectories:YES
                           attributes:nil
                                error:nil];
    }
    NSArray<NSURL *> *sourceFiles = [manager contentsOfDirectoryAtURL:fromURL
                                           includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                              options:0
                                                                error:nil];
    for (NSURL *sourceFile in sourceFiles) {
        NSURL *destFile = [toURL URLByAppendingPathComponent:[sourceFile lastPathComponent]];
        NSNumber *sourceIsDir = @0;
        [sourceFile getResourceValue:&sourceIsDir
                              forKey:NSURLIsDirectoryKey
                               error:nil];
        if ([sourceIsDir boolValue]) {
            [self mergeFolderRecursively:sourceFile
                                      to:destFile];
        } else {
            [self moveFile:sourceFile toURL:destFile overwriteIfExisting:NO];
        }
    }
}

@end