//  Created by Timothy Sanders on 4/4/14.
//
//

#import "HJSKit/HJSKit.h"


NSString * coreDataResetNotificationKey = @"coreDataResetNotification";

static NSString * databaseName = @"Combat_ImpV3.sqlite";
//static NSString * databaseName = @"Prerelease Combat Imp V0.5.sqlite";

static HJSCoreDataCenter * defaultCenter;

@implementation HJSCoreDataCenter {
	BOOL _savePending;
	NSManagedObjectContext * _managedObjectContext;
	NSPersistentStoreCoordinator * _persistentStoreCoordinator;
	NSManagedObjectModel * _managedObjectModel;
}

+ (instancetype)defaultCenter {
	static dispatch_once_t onceToken;
	
	dispatch_once(&onceToken, ^{
		defaultCenter = [HJSCoreDataCenter new];
	});
	return defaultCenter;
}

- (NSManagedObjectContext *)context {
	if (!_managedObjectContext) {
		NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
		if (coordinator != nil) {
			_managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
			[_managedObjectContext setPersistentStoreCoordinator:coordinator];
			// I'm not thrilled by this but I'm pretty sure Core Data is making bogus conflicts on NSOrderedSet
			// properties. Short form: it seems to object to NSManagedObjectID where the description strings don't
			// match, even if those two "different" ID's will return the same NSManagedObject if you try that.
			[_managedObjectContext setMergePolicy:[[NSMergePolicy alloc]
												   initWithMergeType:NSMergeByPropertyObjectTrumpMergePolicyType]];
		}
	}

    return _managedObjectContext;
}

- (void)requestSave {
	if (!_savePending) {
		_savePending = YES;
		[[NSOperationQueue mainQueue] addOperationWithBlock:^{
			[self save];
		}];
	}
}

- (void)immediateSave {
	[self save];
}

- (void)reportDataError {
	HJSDebugCenter * debugCenter = [HJSDebugCenter defaultCenter];
	if ([debugCenter canSendMail]) {
		[debugCenter mailLogWithExplanation:_errorEmailHeader subject:_errorEmailSubject];

	} else {
		UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Data Error"
														 message:_errorNoEmailAlertMessage
														delegate:nil
											   cancelButtonTitle:@"Dismiss"
											   otherButtonTitles:nil];
		
		[alert show];
	}
}

#pragma mark Lifecycle

- (id)init {
	if (defaultCenter) {
		[[HJSDebugCenter defaultCenter] logAtLevel:HJSLogLevelCritical
			formatString:@"Don't create HJSCoreDataCenter objects, use HJSCoreDataCenter defaultCenter instead."];
		return nil;
	}
	
	self = [super init];
	if (self) {
		_errorEmailHeader = @"A serious error accessing your data has happened and your data cannot be recovered. Please send this email to the developer and we'll make every effort to work with you to recover your data. You might be able to use the app by deleting and reinstalling it but be aware that will delete your data forever.";
		_errorEmailSubject = @"HiddenJester Software Data Error";
		_errorNoEmailAlertMessage = @"A serious issue accessing your data has happened and your data cannot be recovered.You might be able to use the app by deleting and reinstalling it but be aware that will delete your data forever. Please contact the developer by emailing bugs@hiddenjester.com and we'll make every effort to work with you to recover your data.";
	}
	return self;
}

#pragma mark Internals

- (void)save {
	NSError * __autoreleasing error = nil;
	[[self context] processPendingChanges];
	if (![[self context] hasChanges]) {
		[[HJSDebugCenter defaultCenter] logAtLevel:HJSLogLevelWarning
									  formatString:@"Core Data save called with no changes pending."];
	}
	if ([[self context] save:&error]) {
		[[HJSDebugCenter defaultCenter] logWithFormatString:@"Data saved successfully"];
	} else {
		[[HJSDebugCenter defaultCenter] logError:error depth:0];
		
		[self resetStack];

		if ([[HJSDebugCenter defaultCenter] canSendMail]) {
			[[HJSDebugCenter defaultCenter] mailLogWithExplanation:@"An issue saving your data has happened. Combat Imp will attempt to recover from this error, but if you're willing to send this email it will help the developer fix the problem.\nPlease feel free to write a short message here describing what you were doing when this occurred. After you close this email Combat Imp will attempt to recover and continue."
														   subject:@"Combat Imp Data Error"];
		} else {
			UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Data Error"
															 message:@"An issue saving your data has happened. Combat Imp will attempt to recover from this error now. If you see this message more than once please contact the developer by emailing bugs@hiddenjester.com."
															delegate:nil
												   cancelButtonTitle:@"Dismiss"
												   otherButtonTitles:nil];
			
			[alert show];
		}
	}
	_savePending = NO;
}

- (void)resetStack {
	[[HJSDebugCenter defaultCenter] logAtLevel:HJSLogLevelWarning formatString:@"Resetting the core data stack."];
	_savePending = NO;
	_managedObjectContext = nil;
	_persistentStoreCoordinator = nil;
	_managedObjectModel = nil;
	[[NSNotificationCenter defaultCenter] postNotificationName:coreDataResetNotificationKey object:self userInfo:nil];
}

- (NSManagedObjectModel *)managedObjectModel
{
	if (!_managedObjectModel) {
		if (!_modelDirName) {
			[[HJSDebugCenter defaultCenter] logAtLevel:HJSLogLevelCritical
										  formatString:@"modelDirName has to be set before the managedObjectModel can be created"];
			return nil;
		}
		NSURL * modelURL = [[NSBundle mainBundle] URLForResource:_modelDirName withExtension:@"momd"];
		_managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
	}
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
	if (!_persistentStoreCoordinator) {
		NSURL * storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:databaseName];
		NSError * __autoreleasing error = nil;
		NSDictionary * options = [NSDictionary dictionaryWithObjectsAndKeys:
								  [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
								  [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
								  nil];
		
		_persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc]
									  initWithManagedObjectModel:[self managedObjectModel]];
		NSPersistentStore * store = [_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
																			  configuration:nil
																						URL:storeURL
																					options:options
																					  error:&error];
		if (!store) {
			[[HJSDebugCenter defaultCenter] logError:error depth:0];
			[self reportDataError];
		} // Couldn't open the store!
	}
    
    return _persistentStoreCoordinator;
}

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end
