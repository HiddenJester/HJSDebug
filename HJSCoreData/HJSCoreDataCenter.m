//  Created by Timothy Sanders on 4/4/14.
//
//

@import UIKit;
@import CoreData;

#import "HJSCoreDataCenter.h"
#import "HJSDebugCenter.h"

NSString * HJSCoreDataCenterCoreDataResetNotificationKey = @"coreDataResetNotification";

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

- (void)resetStack {
	[[HJSDebugCenter existingCenter] logAtLevel:HJSLogLevelWarning
										message:@"HJSCoreData: Resetting the core data stack."];
	_savePending = NO;
	_managedObjectContext = nil;
	_persistentStoreCoordinator = nil;
	_managedObjectModel = nil;
	[[NSNotificationCenter defaultCenter] postNotificationName:HJSCoreDataCenterCoreDataResetNotificationKey
														object:self
													  userInfo:nil];
}

- (BOOL)contextCreated {
	return _managedObjectContext != nil;
}

#pragma mark Lifecycle

- (id)init {
	if (defaultCenter) {
		[[HJSDebugCenter existingCenter]
		 logAtLevel:HJSLogLevelCritical
			message:@"HJSCoreData: Don't create HJSCoreDataCenter objects, use [HJSCoreDataCenter defaultCenter]."];
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
	HJSDebugCenter * debug = [HJSDebugCenter existingCenter];

	[[self context] processPendingChanges];
	if (![[self context] hasChanges]) {
		[debug logAtLevel:HJSLogLevelWarning message:@"HJSCoreData: Core Data save called with no changes pending."];
	}
	if ([[self context] save:&error]) {
		[debug logMessage:@"HJSCoreData: Data saved successfully"];
	} else {
		[debug logError:error];
		[self resetStack];

		if (debug.adHocDebugging) {
			// If we're running in an extension there's nothing to do here but if we're in the full HJSKit we need to
			// try to present an alert asking the user to email the log as soon as possible. presentAlert is added
			// as a category in the full HJSKit (see HJSCoreDataCenter+PresentErrors) so this selector is present in
			// HJSKit, but not in HJSExtension.
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

- (NSManagedObjectModel *)managedObjectModel
{
	if (!_managedObjectModel) {
		if (!_modelDirURL) {
			[[HJSDebugCenter existingCenter]
			 logAtLevel:HJSLogLevelCritical
			 message:@"HJSCoreData: modelDirURL has to be set before the managedObjectModel can be created"];
			return nil;
		}
		[[HJSDebugCenter existingCenter] logFormattedString:@"HJSCoreData: Opening the model dir at %@", _modelDirURL];
		_managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:_modelDirURL];
	}
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
	if (!_persistentStoreCoordinator) {
		if (!_storeURL) {
			[[HJSDebugCenter existingCenter]
			 logAtLevel:HJSLogLevelCritical
			 message:@"HJSCoreData: storeURL has to be set before the persistentStoreCoordinator can be created"];
			return nil;
		}
		NSError * __autoreleasing error = nil;
		NSDictionary * options = [NSDictionary dictionaryWithObjectsAndKeys:
								  [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
								  [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
								  nil];
		
		_persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc]
									  initWithManagedObjectModel:[self managedObjectModel]];
		[[HJSDebugCenter existingCenter] logFormattedString:@"HJSCoreData: Opening the persistent store at %@",
		 _storeURL];
		NSPersistentStore * store = [_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
																			  configuration:nil
																						URL:_storeURL
																					options:options
																					  error:&error];
		if (!store) {
			[[HJSDebugCenter existingCenter] logError:error];
		} // Couldn't open the store!
	}
    
    return _persistentStoreCoordinator;
}

@end
