//  Created by Timothy Sanders on 4/3/14.
//
//

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

@interface HJSDebugCenter : NSObject

@property (nonatomic) HJSLogLevel logLevel;
@property (nonatomic) BOOL adHocDebugging;

+ (instancetype)defaultCenter;

// Raise SIGTRAP in debug, NOP in release
- (void)debugBreak;

#pragma mark Logging Methods

// Logs at HJSLogLevelInfo, so in ad-hoc or debug builds only. This is the drop-in replacement for
// NSLog.
- (void)logWithFormatString:(NSString *)formatString, ... NS_FORMAT_FUNCTION(1, 2);

// Lets you specify the log level to use
- (void)logAtLevel:(HJSLogLevel)level formatString:(NSString *)formatString, ... NS_FORMAT_FUNCTION(2, 3);

// Recursively unpacks NSErrors and logs them in a reasonably pretty-printed format.
// Actually logs at HJSLogLevelCritical, since NSErrors are pretty serious stuff.
- (void)logError:(NSError*)error depth:(int)depth;

// Creates an email containing the log file and displays it for the user to send
- (void)mailLogWithExplanation:(NSString *)explanation;

- (NSString *)logContents;

#pragma mark Configuration Methods

- (void)saveSettings;

- (void)displayControlPanel;

- (BOOL)canSendMail;

#pragma mark Lifecycle Methods

// Call when the app is terminating. This will close the log file and release ASL resources
- (void)terminateLogging;

@end

