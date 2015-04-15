//  Created by Timothy Sanders on 4/3/14.
//
//

@import Foundation;

@class UIViewController;

// Logging sits atop ASL, but I don't want to include ASL.H everywhere, nor do I need
// all 8 logging levels. So we A ) Objective-C-ify the #defines into a NS_ENUM,
// and B ) provide a subset of levels. That's why the actual values are discontinuous.

// Logging at HJSLogLevelCritical will also call debugBreak so we'll stop right at the log point
typedef NS_ENUM(NSInteger, HJSLogLevel) {
	// These log in App Store Builds
	HJSLogLevelCritical = 2,			// ASL_LEVEL_CRIT
	HJSLogLevelWarning = 4,				// ASL_LEVEL_WARNING (also NSLog level)
	// This logs only in ad-hoc builds
	HJSLogLevelInfo = 6,				// ASL_LEVEL_INFO
	// This usually only logs to the debug console, not to the file
	HJSLogLevelDebug = 7				// ASL_LEVEL_DEBUG
};

/// Can be passed as maxLogSize to defaultCenterWithConfigURL
extern const unsigned long long defaultMaxLogSize;

/// KVO string for observing when debugBreak is enabled
extern NSString * debugBreakEnabledKey;

@interface HJSDebugCenter : NSObject

@property (nonatomic) HJSLogLevel logLevel;
@property (nonatomic) BOOL adHocDebugging;
@property (nonatomic) BOOL debugBreakEnabled;

/**
 This is the default way to acquire a HJSDebugCenter object. defaultCenter is a singleton where the first call to
 this will create the center. Future calls merely return the already-configured center. Note the difference between
 this and existingCenter which will not create a new center but will return defaultCenter if it has already been
 initialized.

 If defaultCenter has already been created this returns it. Otherwise it creates defaultCenter to use the specified
 URLs for both the log and the config file and returns the fresh center. maxLogSize sets the threshold where the old
 log will be discarded. If the logfile is less than maxLogSize bytes this center will append to that file.
 defaultMaxLogSize can be passed in for maxLogSize.

 @param configURL A file URL that specifies a settings file to load. If this file does not exist default values will
 be used and saved into this location.

 @param logURL A file URL that specifies a text file to log into. If this file does not exist it will be created. If
 the file already exists but is under maxLogSize bytes it will be opened for appending. If the file exists but is
 over maxLogSize it will be discarded and a new file created.

 @param maxLogSize The maximum file size in bytes that the file at logURL can be before it is discarded and replaced.

 @return A fully configured and ready to log HJSDebugCenter.
 */
+ (HJSDebugCenter *)defaultCenterWithConfigURL:(NSURL *)configURL
										logURL:(NSURL *)logURL
									maxLogSize:(unsigned long long)maxLogSize;

/// If defaultCenter has already been created this returns it. Otherwise it creates defaultCenter with default
/// URLs for both the log and the config file and returns the fresh center.
+ (HJSDebugCenter *)defaultCenter;

/// This will return an existing defaultCenter but otherwise will simply debugBreak and retun nil. It's mostly useful
/// for framework components like the CoreData stack who want to use the logger but would consider an error condition
/// if one was not available.
+ (HJSDebugCenter *)existingCenter;

// Raise SIGTRAP in debug, NOP in release
- (void)debugBreak;

#pragma mark Logging Methods

/// Logs at HJSLogLevelInfo, so in ad-hoc or debug builds only. This is the drop-in replacement for
/// NSLog.
- (void)logFormattedString:(NSString *)formatString, ... NS_FORMAT_FUNCTION(1, 2);
- (void)logMessage:(NSString *)message;
/// Almost-drop-in replacement for NSLog but you can specify the logging level.
- (void)logAtLevel:(HJSLogLevel)level formatString:(NSString *)formatString, ... NS_FORMAT_FUNCTION(2, 3);
/// Log without any string formatting. This is available in Swift, where the formatting can happen during the
/// argument marshalling.
- (void)logAtLevel:(HJSLogLevel)level message:(NSString *)message;

/// Recursively unpacks NSErrors and logs them in a reasonably pretty-printed format.
/// Actually logs at HJSLogLevelCritical, since NSErrors are usually serious stuff.
- (void)logError:(NSError*)error;

#pragma mark Log monitoring Methods
/** 
 The control panel and log mailer can both deal with multiple logs. Although the center only writes to one log
 file you can specify additional logs to display or mail. These additional logs are read-only and not kept open.
 They don't dynamically update, a snapshot is grabbed when needed. The design intent is to support Today extensions,
 which are a separate processes and therefore can have their own logs. The Today extension cannot display the control
 panel or the mail composer, so if it logs to a file location accessible to the main app then the main app can add
 a monitored log using this call.
 
 @param logURL A file URL to the log to monitor

 @param logKey A short string used to identify this log. This string will display in UI in the control panel and will
 be used as the key to a dictionary of log contents.


 @return YES if the log was found and is now monitored, NO if the file could not be found.
 */
- (BOOL)monitorLog:(NSURL *)logURL asKey:(NSString *)logKey;

/**
 Remove a log from the monitored log list.

 @param logKey A short string used to identify the log to remove.
 */
- (void)removeMonitoredLog:(NSString *)logKey;

/// Returns an array of keys for all the currently-monitored logs.
- (NSArray *)monitoredLogKeys;

/// Returns the current main logfile as NSData
- (NSData *)mainLogAsData;
/// Returns the current main logfile as NSString
- (NSString *)mainLogAsString;

/// Returns the log specified in logKey as NSData
- (NSData *)monitoredLogAsData:(NSString *)logKey;
/// Returns the log specified in logKey as NSString
- (NSString *)monitoredLogAsString:(NSString *)logKey;

#pragma mark Configuration Methods

/// Updates the stored plist settings file
- (void)saveSettings;

#pragma mark UI Methods
/**
 Presents a mail containing all monitored logs (as text attachments) and a custom explanation to the user. Customize
 the explanation text so the user can understand why they should send the email.

 @param explanation Text that is put at the top of the email above the log itself.

 @param subject Subject of the email.

 @param presenter The UIViewControler that presents the email panel. Note that this will fail if presenter
	already has a presented view control.

 @return YES if the panel presented, NO if it didn't. Two likely causes of failure: the system won't send email
	or presenter is already presenting a view
 */
- (BOOL)presentMailLogWithExplanation:(NSString *)explanation
							  subject:(NSString *)subject
				   fromViewController:(UIViewController *)presenter;

/// Wrapper around both the permissions for mail as well as the actual "is mail available" checks
- (BOOL)canSendMail;

/**
 Presents the control panel from the presenter.
 
 @param presenter The UIViewControler that presents the control panel. Note that this will fail if presenter
		already has a presented view control.
 
 @return YES if the panel presented, NO if it didn't. (Most likely failure is a presented view already, which
		 prevents presentation in iOS 8.)
 */
- (BOOL)presentControlPanelFromViewController:(UIViewController*)presenter;

#pragma mark Lifecycle Methods
/// Should almost always acquire a center by calling defaultCenter or existingCenter. However, this is the designated
/// initializer that sits under defaultCenter. See the docs for that for argument descriptions.
- (id)initWithConfigURL:(NSURL *)configURL logURL:(NSURL *)logURL maxLogSize:(unsigned long long)maxLogSize;

/// Call when the app is terminating. This will close the log file and release ASL resources
- (void)terminateLogging;

@end
