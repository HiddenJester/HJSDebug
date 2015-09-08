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
	// By default these log in App Store Builds
	HJSLogLevelCritical = 2,			// ASL_LEVEL_CRIT
	HJSLogLevelWarning = 4,				// ASL_LEVEL_WARNING (also NSLog level)
	// By default Info logs in Beta builds
	HJSLogLevelInfo = 6,				// ASL_LEVEL_INFO
	// Debug level messages always log to the debug console, but by default do not go to the file
	HJSLogLevelDebug = 7				// ASL_LEVEL_DEBUG
};

/// Can be passed as maxLogSize to defaultCenterWithConfigURL. Currently 300K.
FOUNDATION_EXPORT const unsigned long long defaultMaxLogSize;

/// KVO string for observing when debugBreak is enabled
FOUNDATION_EXPORT NSString * debugBreakEnabledKey;

@interface HJSDebugCenter : NSObject

/// The current logging level set. Setting this will persist in HJSDebugCenter's own UserDefaults.
@property (nonatomic) HJSLogLevel logLevel;

/// This switch can be used at run-time to decide whether to do something. Note that it *IS* available in
/// release or beta builds. In a builds that do not have BETA defined there is a switch in the Debug
/// control panel that can turn off adHocDebugging. NOTE: if you use that switch on a release build you
/// really can't get it back without interfering via debugger. This value is persisted in HJSDebugCenter's
/// own UserDefaults. I use it to decide whether to add a button to display the Debug control panel to the UI.
@property (nonatomic) BOOL adHocDebugging;

/// Setting this to false shuts off the debugBreak trap. (Note that even if this is set to true it debugBreak still
/// only works if attached to a debugger, and only in DEBUG builds.)
@property (nonatomic) BOOL debugBreakEnabled;

/// In a debug build tells whether a debugger is attached currently. Always false in beta or release
@property (nonatomic, readonly) BOOL debuggerAttached;

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
/// for framework components like the CoreData stack who want to use the logger but would consider it an error condition
/// if one was not available.
+ (HJSDebugCenter *)existingCenter;

/// Raise SIGTRAP in debug if debugBreakEnabled is true & a debugger is attached, NOP in release. If this is a
/// debug build but one of the conditions fails it will log a message.
- (void)debugBreak;

#pragma mark Logging Methods

/// Logs at HJSLogLevelInfo, so in beta or debug builds only. This is the drop-in replacement for
/// NSLog.
- (void)logFormattedString:(NSString *)formatString, ... NS_FORMAT_FUNCTION(1, 2);

/// Almost-drop-in replacement for NSLog but you can specify the logging level.
- (void)logAtLevel:(HJSLogLevel)level formatString:(NSString *)formatString, ... NS_FORMAT_FUNCTION(2, 3);

/// Non-variadic logging at HJSLogLevelInfo. More useful in Swift which has built-in string formatting.
- (void)logMessage:(NSString *)message;

/// Log without any string formatting. This is mostly for Swift where the formatting can happen during the
/// argument marshalling, but can be called from Obj-C if you don't need string expansion.
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

/// Returns a snapshot of the main logfile as NSData
- (NSData *)mainLogAsData;

/// Returns the current main logfile as NSString
- (NSString *)mainLogAsString;

/// Returns the log specified in logKey as NSData
- (NSData *)monitoredLogAsData:(NSString *)logKey;

/// Returns the log specified in logKey as NSString
- (NSString *)monitoredLogAsString:(NSString *)logKey;

#pragma mark Configuration Methods

/// Updates the stored plist settings file. Note that changing a setting doesn't call saveSettings, so if you want
/// a permanent change be sure to call saveSettings.
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
/// Call when the app is terminating. This will close the log file and release ASL resources
- (void)terminateLogging;

@end
