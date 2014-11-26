//  Created by Timothy Sanders on 4/4/14.
//
//

@import UIKit;
@import CoreData;

#import "HJSCoreDataCenter.h"

#import "HJSExtension.h"

NSString * HJSCoreDataCenterResetNotificationKey = @"coreDataResetNotification";

static NSString * defaultEmailHeader =
@"A serious error accessing your data has happened and your data cannot be recovered. Please send this email to the developer and we'll make every effort to work with you to recover your data. You might be able to use the app by deleting and reinstalling it but be aware that will delete your data forever.";
static NSString * defaultEmailSubject = @"HiddenJester Software Data Error";
static NSString * defaultNoEmailAlertMessage =
@"A serious issue accessing your data has happened and your data cannot be recovered.You might be able to use the app by deleting and reinstalling it but be aware that will delete your data forever. Please contact the developer by emailing bugs@hiddenjester.com and we'll make every effort to work with you to recover your data.";


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

#pragma mark Lifecycle

- (id)init {
	if (defaultCenter) {
		[[HJSDebugCenter defaultCenter] logAtLevel:HJSLogLevelCritical
			formatString:@"Don't create HJSCoreDataCenter objects, use HJSCoreDataCenter defaultCenter instead."];
		return nil;
	}
	
	self = [super init];
	if (self) {
		_errorEmailHeader = defaultEmailHeader;
		_errorEmailSubject = defaultEmailSubject;
		_errorNoEmailAlertMessage = defaultNoEmailAlertMessage;
	}
	return self;
}

#pragma mark Internals

- (void)save {
	NSError * __autoreleasing error = nil;
	HJSDebugCenter * debug = [HJSDebugCenter defaultCenter];

	[[self context] processPendingChanges];
	if (![[self context] hasChanges]) {
		[debug logAtLevel:HJSLogLevelWarning formatString:@"Core Data save called with no changes pending."];
	}
	if ([[self context] save:&error]) {
		[debug logMessage:@"Data saved successfully"];
	} else {
		[debug logError:error];
		[self resetStack];

		if (debug.adHocDebugging) {
			// If we're running in an extension there's nothing to do here but if we're in the full HJSKit we need to
			// try to present an alert asking the user to email the log as soon as possible. presentAlert is added
			// as a category in the full HJSKit so this selector is present in HJSKit, but not in HJSExtension.
			SEL presentAlert = NSSelectorFromString(@"presentAlert");
			if ([self respondsToSelector:presentAlert]) {
				// Reassure ARC we aren't leaking anything by building a NSInvocation
				NSMethodSignature * methodSig = [[self class] instanceMethodSignatureForSelector:presentAlert];
				NSInvocation * invocation = [NSInvocation invocationWithMethodSignature:methodSig];
				[invocation setSelector:presentAlert];
				[invocation setTarget:self];
				[invocation invoke];
			}
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
	[[NSNotificationCenter defaultCenter] postNotificationName:HJSCoreDataCenterResetNotificationKey object:self userInfo:nil];
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
		if (!_databaseName) {
			[[HJSDebugCenter defaultCenter] logAtLevel:HJSLogLevelCritical
										  formatString:@"databaseName has to be set before the persistentStoreCoordinator can be created"];
			return nil;
		}
		NSURL * storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:_databaseName];
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
			[[HJSDebugCenter defaultCenter] logError:error];
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
