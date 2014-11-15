//  Created by Timothy Sanders on 4/3/14.
//
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

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

// At startup if there is no settings file we create one suitable for retail builds
// with a logging level of warning and Ad-Hoc debugging set to NO. If BETA is #defined then
// the logging level is set to Info and Ad-Hoc debugging is set to YES. Furthermore
// if DEBUG is #defined then we ALSO set the log level to Debug and Ad-Hoc to YES. Note
// that a debug build will then *persist* those settings into the file.
@interface HJSDebugCenter : NSObject

@property (nonatomic) HJSLogLevel logLevel;
@property (nonatomic) BOOL adHocDebugging;

+ (HJSDebugCenter *)defaultCenter;

// Raise SIGTRAP in debug, NOP in release
- (void)debugBreak;

#pragma mark Logging Methods

// Logs at HJSLogLevelInfo, so in ad-hoc or debug builds only. This is the drop-in replacement for
// NSLog.
- (void)logFormattedString:(NSString *)formatString, ... NS_FORMAT_FUNCTION(1, 2);
- (void)logMessage:(NSString *)message;
// Lets you specify the log level to use
- (void)logAtLevel:(HJSLogLevel)level formatString:(NSString *)formatString, ... NS_FORMAT_FUNCTION(2, 3);
// Versions without formatting for Swift (which can do the string formatting itself)
- (void)logAtLevel:(HJSLogLevel)level message:(NSString *)message;

// Recursively unpacks NSErrors and logs them in a reasonably pretty-printed format.
// Actually logs at HJSLogLevelCritical, since NSErrors are usually serious stuff.
- (void)logError:(NSError*)error;

/**
 Presents a mail containing the log and a custom exmplanation to the user. Customize the 
	explanation text so the user can understand why they should send the email.

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

- (BOOL)canSendMail;

- (NSString *)logContents;

#pragma mark Configuration Methods

- (void)saveSettings;
/**
 Presents the control panel from the presenter.
 
 @param presenter The UIViewControler that presents the control panel. Note that this will fail if presenter
		already has a presented view control.
 
 @return YES if the panel presented, NO if it didn't. (Most likely failure is a presented view already, which
		 prevents presentation in iOS 8.)
 */
- (BOOL)presentControlPanelFromViewController:(UIViewController*)presenter;

#pragma mark Lifecycle Methods

// Call when the app is terminating. This will close the log file and release ASL resources
- (void)terminateLogging;

@end
