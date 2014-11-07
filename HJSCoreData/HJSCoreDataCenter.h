//  Created by Timothy Sanders on 4/4/14.
//
//

/**
 HJSCoreDataCenter will post this notification when it needs to reset the stack. Generally this happens when the merge
	policy has kicked in and done something weird. But if you need to reload your model objects on a reset this
	notification is the way to  do so.
 */
extern NSString * HJSCoreDataCenterResetNotificationKey;

/**
 This wraps an entire Core Data stack, complete with the ability to restart the stack in the event
	of a data error. This is a singleton object, the proper way to get a center is via the class call
	defaultCenter. [HJSCoreDataCenter defaultCenter]

 @warning You must set defaultCenter.modelDirName and defaultCenter.databaseName before you do anything that
	will actually create the Core Data objects.

 HJSCoreDataCenter attempts to recover from certain types of merge errors and that can cause the stack to reset
	itself. If you need to reload model objects when that happens register an observer on
	coreDataResetNotificationKey, there will be no userData.

 Other than that the major uses are to get the NSManagedObject context via [defaultCenter context] and to
	request a save via [defaultCenter requestSave]. Note that all operations occur on the main thread as my apps
	all have reasonably small databases. requestSave does queue a save to occur in the future and will only
	schedule one save at a time so you can freely call requestSave after any data change: if you call it ten times
	in quick succession it will only result in one coalesced save request.
 */
@interface HJSCoreDataCenter : NSObject

/**
 This is the string used to build the URL for the momD folder. We'll look for <modelDirName>.momd in the main
	bundle and use that to get the NSManagedObjectModel.

 Set it BEFORE you do anything that requires the managedObjectModel or you'll get an assert.
 */
@property (nonatomic) NSString * modelDirName;

/**
 This is the string used to build the URL for the persistent store folder. We'll look for <databaseName> in the
	application documents directory. Note that this means it should be fully qualifed, ie. "name.sqlite"

 Set it BEFORE you do anything that requires the persistentStoreCoordinator or you'll get an assert.
 */
@property (nonatomic) NSString * databaseName;

/**
 When reportDataError is called it will attempt to create an email for the user to send to us containing the
	log. errorEmailHeader will be put in the body of the proposed message above the log. There is a default
	message provided if this isn't customized.
 */
@property (nonatomic) NSString * errorEmailHeader;

/**
 When reportDataError is called it will attempt to create an email for the user to send to us containing the
	log. errorEmailSubject will be put in the subject of the proposed message. There is a default
	message provided if this isn't customized.
 */
@property (nonatomic) NSString * errorEmailSubject;

/**
 When reportDataError is called if mail cannot be sent then an alert dialog will be displayed containing
	errorNoEmailAlertMessage. There is a default message provided if this isn't customized.
 */
@property (nonatomic) NSString * errorNoEmailAlertMessage;

/**
 This class method returns the singleton HJSCoreDataCenter
 
 @result a configured and running HJSCoreDataCenter
 */
+ (instancetype)defaultCenter;

/**
 @warning You really need to configure modelDirName and databaseName before calling context.

 @result a NSManagedObjectContext that is configured and ready for use.
 */
- (NSManagedObjectContext *)context;

/**
 If a save has been requested but not yet executed this does nothing. When a save is requested the save operation
	is put on the mainQueue for later execution. This makes coalescing multiple requests easy. Just call requestSave
	after every data change and big sweeping changes will still only trigger a single Core Data save.

 @result No return value but at some point in the future a Core Data save will happen on the main operation queue.
 */
- (void)requestSave;

/**
 This is mostly a debugging aid. It triggers an immediate save. Note that this does not remove the future save if
	requestSave is called.

 @result Core Data immediately saves.
 */
- (void)immediateSave; // Mostly a debugging aid, but can be useful to force a save RIGHT NOW

/**
 This is a convenience method that will attempt to send an email containing the log. If mail cannot be sent it will
	present a modal alert dialog alerting the user a data error has occurred.
 
 @param presenter A View Controller that will present the mail dialog.

 @result The user is either presented an email to send or an alert dialog informing them there has been an error.
 */
- (void)presentErrorEmailFromViewController:(UIViewController *)presenter;

@end