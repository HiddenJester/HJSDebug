//  Created by Timothy Sanders on 4/4/14.
//
//

/*!
	@const coreDataResetNotificationKey
	@discussion We'll post this notification when we need to reset the stack. Generally this happens when the merge
		policy has kicked in and done something weird. But if you need to reload your model objects on a reset this
		notification is the way to do so.
 */
extern NSString * coreDataResetNotificationKey;

/*!
	@class HJSCoreDataCenter
	@discussion 
		This wraps an entire Core Data stack, complete with the ability to restart the stack in the event
		of a data error. This is a singleton object, the proper way to get a center is via the class call
		defaultCenter. [HJSCoreDataCenter defaultCenter]
 
		IMPORTANT: You must set defaultCenter.modelDirName before you do anything that will actually create the
		Core Data objects.
 
		HJSCoreDataCenter attempts to recover from certain types of merge errors and that can cause the stack to reset
		itself. If you need to reload model objects when that happens register an observer on 
		coreDataResetNotificationKey, there will be no userData.
 */
@interface HJSCoreDataCenter : NSObject


/*!
	@property: modelDirName
		This is the string used to build the URL for the momD folder. We'll look for <modelDirName>.momd in the main
		bundle and use that to get the NSManagedObjectModel. Set it BEFORE you do anything that requires the
		managedObjectModel or you'll get an assert
 */
 @property (nonatomic) NSString * modelDirName;

// These strings will be displayed when reportDataError is called.
// If they are not set then a generic message will be used.
/*!
	@property: errorEmailHeader
		When reportDataError is called it will attempt to create an email for the user to send to us containing the
		log. errorEmailHeader will be put in the body of the proposed message above the log. There is a default
		message provided if this isn't customized.
 */
@property (nonatomic) NSString * errorEmailHeader;
/*!
	@property: errorEmailSubject
		When reportDataError is called it will attempt to create an email for the user to send to us containing the
		log. errorEmailSubject will be put in the subject of the proposed message. There is a default
		message provided if this isn't customized.
 */
@property (nonatomic) NSString * errorEmailSubject;
/*!
	@property: errorNoEmailAlertMessage
		When reportDataError is called if mail cannot be sent then an alert dialog will be displayed containing
		errorNoEmailAlertMessage. There is a default message provided if this isn't customized.
 */
@property (nonatomic) NSString * errorNoEmailAlertMessage;

+ (instancetype)defaultCenter;

- (NSManagedObjectContext *)context;

- (void)requestSave;
- (void)immediateSave; // Mostly a debugging aid, but can be useful to force a save RIGHT NOW

- (void)reportDataError;

@end
