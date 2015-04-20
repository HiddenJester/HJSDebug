//  Created by Timothy Sanders on 4/4/14.
//
//

@class NSManagedObjectContext;
@class NSPersistentStoreCoordinator;
@class UIViewController;

/**
 HJSCoreDataCenter will post this notification when it needs to reset the stack. Generally this happens when the merge
	policy has kicked in and done something weird. But if you need to reload your model objects on a reset this
	notification is the way to  do so.
 */
extern NSString * HJSCoreDataCenterCoreDataResetNotificationKey;

/**
 This wraps an entire Core Data stack, complete with the ability to restart the stack in the event
	of a data error. This is a singleton object, the proper way to get a center is via the class call
	defaultCenter. [HJSCoreDataCenter defaultCenter]

 @warning You must set defaultCenter.modelDirURL and defaultCenter.databaseName before you do anything that
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
 This is the URL for the momD folder. We'll get the NSManagedObjectModel from here.

 Set it BEFORE you do anything that requires the managedObjectModel or you'll get an assert.
 */
@property (nonatomic) NSURL * modelDirURL;

/**
 This is the NSURL for the persistent store. This should be fully qualified, be it in the application
	documents directory, or an app group, or some other locale.
 Set it BEFORE you do anything that requires the persistentStoreCoordinator or you'll get an assert.
 */
@property (nonatomic) NSURL * storeURL;

/**
 When presentErrorEmailFromViewController is called it will attempt to create an email for the user to send to us 
	containing the log. errorEmailHeader will be put in the body of the proposed message above the log. There is a
	default message provided if this isn't customized. Note that presentErrorEmailFromViewController isn't in
	HJSExtension, only in the full kit, but it's easier to just have the properties here because the category providing
	presentErrorEmailFromViewController doesn't have ivars.
 */
@property (nonatomic) NSString * errorEmailHeader;

/**
 When presentErrorEmailFromViewController is called it will attempt to create an email for the user to send to us 
	containing the log. errorEmailSubject will be put in the subject of the proposed message. There is a default
	message provided if this isn't customized. Note that presentErrorEmailFromViewController isn't in
	HJSExtension, only in the full kit, but it's easier to just have the properties here because the category providing
	presentErrorEmailFromViewController doesn't have ivars.
 */
@property (nonatomic) NSString * errorEmailSubject;

/**
 When presentErrorEmailFromViewController is called if mail cannot be sent then an alert dialog will be displayed
	containing errorNoEmailAlertMessage. There is a default message provided if this isn't customized. Note that
	presentErrorEmailFromViewController isn't in HJSExtension, only in the full kit, but it's easier to just have the 
	properties here because the category providing presentErrorEmailFromViewController doesn't have ivars.
 */
@property (nonatomic) NSString * errorNoEmailAlertMessage;

/**
 This class method returns the singleton HJSCoreDataCenter
 
 @result a configured and running HJSCoreDataCenter
 */
+ (instancetype)defaultCenter;

/**
 @warning You really need to configure modelDirURL and databaseName before calling context.

 @result a NSManagedObjectContext that is configured and ready for use.
 */
- (NSManagedObjectContext *)context;

/**
 The coordinator that will be used by context.

 @warning You really need to configure modelDirURL and databaseName before calling coordinator.

 @result a NSPersistentStoreCoordinator that is configured and ready for use.
 */
- (NSPersistentStoreCoordinator *)coordinator;

/**
 If a save has been requested but not yet executed this does nothing. When a save is requested the save operation
	is put on the mainQueue for later execution. This makes coalescing multiple requests easy. Just call requestSave
	after every data change and big sweeping changes will still only trigger a single Core Data save.

 There is no return value but at some point in the future a Core Data save will happen on the main operation queue.
 */
- (void)requestSave;

/**
 Unlike requestSave this triggers an immediate save. Note that a save from requestSave is pending it is not removed by
 this call but will still happen in the future.

 There is no return value but Core Data immediately saves.
 */
- (void)immediateSave;

/**
 This is mostly a debugging aid, so you can verify you correctly handle HJSCoreDataCenterCoreDataResetNotificationKey.
	Calling this reset the entire Core Data stack, which will recreate itself as needed. This function is called
	internally when an error arises during a save in an attempt to recover normal operation. The "normal" reason I 
	see resets has to do with the merge policy: see the comment in context for more info about that.

 @warning THIS DOES NOT SAVE any pending changes. It can be called during error conditions arising from a save so it
	does not call save. If you want to save first be sure to call immediateSave prior to resetStack.
 */
- (void)resetStack;

/**
 This method lets you know if the context is already created.
 
 @result YES if context has been created, NO otherwise
 */
- (BOOL)contextCreated;

/**
 This is a convenience method that will attempt to send an email containing the log. If mail cannot be sent it will
 present a modal alert dialog alerting the user a data error has occurred.

 @param presenter A View Controller that will present the mail dialog.

 There is no return but the user is either presented an email to send or an alert dialog informing them there has
 been an error.
 */
- (void)presentErrorEmailFromViewController:(UIViewController *)presenter;

@end
