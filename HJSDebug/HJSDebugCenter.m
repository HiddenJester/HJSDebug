//  Created by Timothy Sanders on 4/3/14.
//
//

#import "HJSDebugCenter.h"

#include <asl.h>					// Logging sits atop ASL
#include <sys/sysctl.h>				// Need several things for debuggerAttached

@import CoreData.CoreDataErrors;	// Need definition of NSDetailedErrorsKey

#import "HJSDebugMailComposeDelegate.h"
#import "HJSDebugCenterControlPanelViewController.h"

// MARK: Exported Constants
NSString * debugBreakEnabledKey = @"debugBreakEnabled";
const unsigned long long defaultMaxLogSize = 300 * 1024;


// MARK: Internal constants
static NSString * loggingLevelKey = @"LoggingLevel";
static NSString * adHocDebuggingKey = @"adHocDebugging";

/// Our private singleton
static HJSDebugCenter * defaultCenter;

@implementation HJSDebugCenter {
	// Runtime storage of the settings plist
	NSMutableDictionary * _settings;
	NSURL * _settingsFileURL;
	
	// Logging bits
	aslclient _aslClient;
	NSFileHandle * _logFile;
	NSURL * _logFileURL;

	// Monitored logs
	NSMutableDictionary * _monitoredLogs;

	HJSDebugMailComposeDelegate * _mailComposeDelegate;
}

+ (HJSDebugCenter *)defaultCenter {
	if (defaultCenter) {
		return defaultCenter;
	}
	
	static NSString * logFilename = @"HJSDebugLog.txt";
	static NSString * configFilename = @"HJSDebugSettings.plist";
	NSError * __autoreleasing  error;
	NSURL * logURL = [[NSFileManager defaultManager] URLForDirectory:NSCachesDirectory
															inDomain:NSUserDomainMask
												   appropriateForURL:nil
															  create:YES
															   error:&error];
	if (error) {
		// Argh. Can't use defaultCenter here, it doesn't exist yet.
		NSLog(@"%@", error.description);
	} else {
		logURL = [logURL URLByAppendingPathComponent:logFilename];
	}

	// Create the config URL
	NSURL * configURL = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
															   inDomain:NSUserDomainMask
													  appropriateForURL:nil
																 create:YES
																  error:&error];
	if (error) {
		// Argh. Can't use defaultCenter here, it doesn't exist yet.
		NSLog(@"%@", error.description);
	} else {
		configURL = [configURL URLByAppendingPathComponent:configFilename];
	}

	return [HJSDebugCenter defaultCenterWithConfigURL:configURL logURL:logURL maxLogSize:defaultMaxLogSize];
}

+ (HJSDebugCenter *)defaultCenterWithConfigURL:(NSURL *)configURL logURL:(NSURL *)logURL maxLogSize:(unsigned long long)maxLogSize {
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		defaultCenter = [[HJSDebugCenter alloc] initWithConfigURL:configURL logURL:logURL maxLogSize:maxLogSize];
	});
	return defaultCenter;
}

+ (HJSDebugCenter *)existingCenter {
	if (defaultCenter) {
		return defaultCenter;
	}
	// Otherwise, make a default one, debug break about it, then destroy it.
	HJSDebugCenter * tempCenter = [HJSDebugCenter defaultCenter];
	[tempCenter logAtLevel:HJSLogLevelCritical message:@"existingCenter called with no center provided."];
	defaultCenter = nil;
	return nil;
}

#pragma mark Properties

- (void)setLogLevel:(HJSLogLevel)level {
	NSNumber * loggingLevel = [NSNumber numberWithInteger:level];
	[_settings setObject:loggingLevel forKey:loggingLevelKey];

	switch (level) {
		case HJSLogLevelCritical:
			[self logMessage:@"Log level set to critical."];
			break;

		case HJSLogLevelWarning:
			[self logMessage:@"Log level set to warning."];
			break;

		case HJSLogLevelInfo:
			[self logMessage:@"Log level set to info."];
			break;

		case HJSLogLevelDebug:
			[self logMessage:@"Log level set to debug."];
			break;

		default:
			break;
	}

	asl_set_filter(_aslClient, ASL_FILTER_MASK_UPTO(level));
	if (_logFile) {
		asl_set_output_file_filter(_aslClient, _logFile.fileDescriptor, ASL_FILTER_MASK_UPTO(level));
	}
}

- (HJSLogLevel)logLevel {
	return [[_settings objectForKey:loggingLevelKey] integerValue];
}

- (void)setAdHocDebugging:(BOOL)adHocDebugging {
	NSNumber * adHocFlag = [NSNumber numberWithBool:adHocDebugging];
	[_settings setObject:adHocFlag forKey:adHocDebuggingKey];
	adHocDebugging ? [self logMessage:@"Ad-hoc enabled"] : [self logMessage:@"Ad-hoc disabled"];
}

- (BOOL)adHocDebugging {
	return [[_settings objectForKey:adHocDebuggingKey] boolValue];
}

- (void)setDebugBreakEnabled:(BOOL)debugBreakEnabled {
	NSNumber * debugBreakFlag = [NSNumber numberWithBool:debugBreakEnabled];
	[_settings setObject:debugBreakFlag forKey:debugBreakEnabledKey];
	debugBreakEnabled ? [self logMessage:@"debugBreak enabled"] : [self logMessage:@"debugBreak disabled"];
}

- (BOOL)debugBreakEnabled {
	return [[_settings objectForKey:debugBreakEnabledKey] boolValue];
}

- (BOOL)debuggerAttached {
	// This code comes from TechNote QA13161: https://developer.apple.com/library/mac/qa/qa1361/_index.html
	// The code says it should only be used in a debug build so under release builds it always returns NO,
	// even if there is a debugger attached.
#if DEBUG
	int                 junk;
	int                 mib[4];
	struct kinfo_proc   info;
	size_t              size;

	// Initialize the flags so that, if sysctl fails for some bizarre
	// reason, we get a predictable result.

	info.kp_proc.p_flag = 0;

	// Initialize mib, which tells sysctl the info we want, in this case
	// we're looking for information about a specific process ID.

	mib[0] = CTL_KERN;
	mib[1] = KERN_PROC;
	mib[2] = KERN_PROC_PID;
	mib[3] = getpid();

	// Call sysctl.

	size = sizeof(info);
	junk = sysctl(mib, sizeof(mib) / sizeof(*mib), &info, &size, NULL, 0);
	assert(junk == 0);

	// We're being debugged if the P_TRACED flag is set.

	return ( (info.kp_proc.p_flag & P_TRACED) != 0 );
#else
	return NO;
#endif
}

# pragma mark Debug only methods
// Public access to debugBreak - which will log if it can't actually break.
- (void)debugBreak {
	[self debugBreakWithLoggingEnabled:YES];
}

// Internal method, used in places where we've already logged something else and don't need to log more about the break.
- (void)debugBreakNoLogging {
	[self debugBreakWithLoggingEnabled:NO];
}

// Internal handler of both debugBreak & debugBreakNoLogging.
- (void)debugBreakWithLoggingEnabled:(BOOL)loggingEnabled {
#if DEBUG
	// First check to see if the debug option is live
	if (!self.debugBreakEnabled) {
		if (loggingEnabled) {
			[self logAtLevel:HJSLogLevelDebug formatString:@"debugBreak called, but is disabled via options."];
		}
		return;
	}
	// Then see if there is a debugger attached
	if (!self.debuggerAttached) {
		if (loggingEnabled) {
			[self logAtLevel:HJSLogLevelDebug formatString:@"debugBreak called, but no debugger is attached."];
		}
		return;
	}
	// OK, both tests passed, break!
	raise(SIGTRAP);
#endif
}

#pragma mark Logging methods

- (void)logFormattedString:(NSString *)formatString, ... {
    va_list args;
    va_start(args, formatString);

	[self logMessage:[[NSString alloc] initWithFormat:formatString arguments:args]
			   level:HJSLogLevelInfo
		   skipBreak:YES];

	va_end(args);
}

- (void)logAtLevel:(HJSLogLevel)level formatString:(NSString *)formatString, ... {
    va_list args;
    va_start(args, formatString);
	
	[self logMessage:[[NSString alloc] initWithFormat:formatString arguments:args]
			   level:level
		   skipBreak:NO];

    va_end(args);
}

- (void)logAtLevel:(HJSLogLevel)level message:(NSString *)message {
	[self logMessage:message level:level skipBreak:NO];
}

- (void)logMessage:(NSString *)message {
	[self logMessage:message level:HJSLogLevelInfo skipBreak:NO];
}

- (void)logError:(NSError *)error {
	[self logError:error atDepth:0];
}

- (void)logError:(NSError *)error atDepth:(int)depth {
	NSMutableString * tempLeader = [[NSMutableString alloc] initWithString:@""];
	
	for (int i = 0; i < depth; ++i) {
		[tempLeader appendString:@"    "];
	}
	NSString * leader = [tempLeader copy];
	
	[self logFormattedString:@"%@Logging error at depth %d", leader, depth];
    if ([error.userInfo objectForKey:NSDetailedErrorsKey]) {
        for (NSError* subError in [error.userInfo objectForKey:NSDetailedErrorsKey]) {
            [self logError:subError atDepth:depth + 1];
        }
    }
    else {
        [self logFormattedString:@"%@Error %ld %@ userInfo:", leader, (long)error.code, error.localizedDescription];
		[error.userInfo enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
			[self logFormattedString:@"%@ key:%@", leader, key];
			NSArray * lines = [[obj description] componentsSeparatedByString:@"\\n"];
			for (NSString * line in lines) {
				NSString * output = [NSString stringWithFormat:@"%@   %@", leader, line];
				[self logMessage:output level:HJSLogLevelCritical skipBreak:YES];
			}
		}];
		if (depth == 0) { // We're done logging, time to break
			[self debugBreakNoLogging];
		}
    }
}

#pragma mark Mail Log methods

- (BOOL)presentMailLogWithExplanation:(NSString *)explanation
							  subject:(NSString *)subject
				   fromViewController:(UIViewController *)presenter {
	static NSString * mimeType = @"plain/text";

	if (!presenter) {
		[self logAtLevel:HJSLogLevelCritical
			formatString:@"Must provide presenter to present ControlPanel."];
		return NO;
	}
	if (presenter.presentedViewController) {
		[self logAtLevel:HJSLogLevelCritical
			formatString:@"Can't present ControlPanel while another view is presented."];
		return NO;
	}

	if (![self canSendMail]) {
		[self logFormattedString:@"Mail is not enabled, log cannot be sent."];
		return NO;
	}

	MFMailComposeViewController * mailController = [MFMailComposeViewController new];
	if (!_mailComposeDelegate) {
		_mailComposeDelegate = [HJSDebugMailComposeDelegate new];
	}
	mailController.mailComposeDelegate = _mailComposeDelegate;

	[mailController setSubject:subject];
	[mailController setToRecipients:@[@"bugs@hiddenjester.com"]];
	
	[mailController setMessageBody:explanation isHTML:NO];
	[mailController addAttachmentData:self.mainLogAsData mimeType:mimeType fileName:_logFileURL.lastPathComponent];
	[_monitoredLogs enumerateKeysAndObjectsUsingBlock:^(NSString * key, NSURL * url, BOOL *stop) {
		NSData * log = [self monitoredLogAsData:key];
		if (log) {
			[mailController addAttachmentData:log mimeType:mimeType fileName:url.lastPathComponent];
		}
	}];

	[presenter presentViewController:mailController animated:YES completion:^{
		if (presenter.presentedViewController != mailController) {
			[self logAtLevel:HJSLogLevelCritical formatString:@"Couldn't present the mail dialog."];
		}
	}];
	return YES;
}

- (BOOL)canSendMail {
	// Could an option in the future to permanently disable mail
	return [MFMailComposeViewController canSendMail];
}

#pragma mark Log monitoring Methods
- (BOOL)monitorLog:(NSURL *)logURL asKey:(NSString *)logKey {
	if ([[NSFileManager defaultManager] fileExistsAtPath:logURL.path]) {
		[_monitoredLogs setObject:logURL forKey:logKey];
		return YES;
	}
	return NO;
}

- (void)removeMonitoredLog:(NSString *)logKey {
	[_monitoredLogs removeObjectForKey:logKey];
}

- (NSArray *)monitoredLogKeys {
	return _monitoredLogs.allKeys;
}

- (NSData *)mainLogAsData {
	NSError * __autoreleasing error;
	NSData * log = [NSData dataWithContentsOfFile:_logFileURL.path options:NSDataReadingUncached error: &error];
	if (!log) {
		[self logError:error];
	}
	return log;
}

- (NSString *)mainLogAsString {
	return [[NSString alloc] initWithData:self.mainLogAsData encoding:NSUTF8StringEncoding];
}

- (NSData *)monitoredLogAsData:(NSString *)logKey {
	NSURL * logURL = [_monitoredLogs objectForKey:logKey];

	if (logURL) {
		NSError * __autoreleasing error;
		NSData * log = [NSData dataWithContentsOfFile:logURL.path options:NSDataReadingUncached error: &error];
		if (!log) {
			[self logError:error];
		}
		return log;
	}
	return nil;
}

- (NSString *)monitoredLogAsString:(NSString *)logKey {
	return [[NSString alloc] initWithData:[self monitoredLogAsData:logKey] encoding:NSUTF8StringEncoding];
}

# pragma mark Configuration Methods

- (void)saveSettings {
	if ([_settings writeToURL:_settingsFileURL atomically:YES]) {
		[self logAtLevel:HJSLogLevelDebug formatString:@"Debug settings file saved successfully."];
	} else {
		[self logAtLevel:HJSLogLevelCritical formatString:@"Debug settings file failed to save."];
	}
}

#pragma mark Control Panel methods

- (BOOL)presentControlPanelFromViewController:(UIViewController*)presenter {
	if (!presenter) {
		[self logAtLevel:HJSLogLevelCritical
			formatString:@"Must provide presenter to present ControlPanel."];
		return NO;
	}
	if (presenter.presentedViewController) {
		[self logAtLevel:HJSLogLevelCritical
			formatString:@"Can't present ControlPanel while another view is presented."];
		return NO;
	}

	HJSDebugCenterControlPanelViewController * panelController = [HJSDebugCenterControlPanelViewController new];
	NSBundle * myBundle = [NSBundle bundleForClass:self.class];
	if (!myBundle) {
		[self logAtLevel:HJSLogLevelCritical formatString:@"Can't find the ControlPanel bundle."];
		return NO;
	}
	NSArray * objects = [myBundle loadNibNamed:@"HJSDebugCenterControlPanel"
													  owner:panelController
													options:nil];
	if (!objects || objects.count == 0) {
		[self logAtLevel:HJSLogLevelCritical formatString:@"Can't find the ControlPanel in the bundle."];
		return NO;
	}

	panelController.view = objects[0];
	[presenter presentViewController:panelController animated:YES completion:^{
		// I dunno, did that work?
		if (presenter.presentedViewController != panelController) {
			[self logAtLevel:HJSLogLevelCritical formatString:@"Couldn't present the ControlPanel."];
		}
	}];
	return YES;
}

#pragma mark Lifecycle
- (id)init {
	if (defaultCenter) {
		[self logAtLevel:HJSLogLevelCritical
			formatString:@"Don't create HJSDebugCenter objects, use HJSDebugCenter defaultCenter instead."];
		return defaultCenter;
	}

	return [HJSDebugCenter defaultCenter];
}

- (id)initWithConfigURL:(NSURL *)configURL logURL:(NSURL *)logURL maxLogSize:(unsigned long long)maxLogSize {
	NSError * __autoreleasing error;

	if (defaultCenter) {
		[self logAtLevel:HJSLogLevelCritical
			formatString:@"Don't create HJSDebugCenter objects, use HJSDebugCenter defaultCenter instead."];
		return defaultCenter;
	}

    self = [super init];
    if (self) {
		_settingsFileURL = configURL;
		// Doesn't really give back an error. Either we get data or we get nil. NOTE that means _settings isn't
		// loaded for certain until the if (!_settings) below.
		_settings = [[NSDictionary dictionaryWithContentsOfURL:_settingsFileURL] mutableCopy];

		//set up the aslClient
		_aslClient = asl_open(NULL, NULL, ASL_OPT_NO_DELAY | ASL_OPT_STDERR);

		_logFileURL = logURL;

		NSFileManager * manager = [NSFileManager defaultManager];

		// Check to see if the logfile already exists, assume we need to create (or overwrite) the file
		BOOL createFile = YES;
		unsigned long long fileSize = 0; // If we decide to reset the log file, store the old size here.
		if ([manager fileExistsAtPath:_logFileURL.path]) {
			// If the file exists, determine whether it is is below the size threshold
			NSDictionary * attribs = [manager attributesOfItemAtPath:_logFileURL.path error:&error];
			if (!attribs) {
				[self logError:error];
			}
			else {
				if ([attribs fileSize] < maxLogSize) {
					createFile = NO;
				}
				else {
					fileSize = [attribs fileSize];
				}
			}
		}
		if (createFile) {
			[manager createFileAtPath:_logFileURL.path contents:nil attributes:nil];
		}

		// OK, by now we either have decided we can append to the file or we've created one.
		_logFile = [NSFileHandle fileHandleForUpdatingURL:_logFileURL error:&error];
		[_logFile readDataToEndOfFile]; // Skip to the end of the file

		if (!_logFile) {
			[self logError:error];
		} else {
			asl_add_log_file(_aslClient, _logFile.fileDescriptor);
		}

		[self logFormattedString:@"Logging to %@", _logFileURL];
		if (fileSize > 0) {
			[self logFormattedString:@"Discarded old log file of %llu bytes", fileSize];
		}

		// If we didn't load settings from the specified file make fresh ones
		if (!_settings) {
			[self createSettings];
		}
		else {
			// Set the log level as specified
			[self setLogLevel:[[_settings objectForKey:loggingLevelKey] integerValue]];
			[self logFormattedString:@"Debug settings file loaded from %@", _settingsFileURL];
		}

		[self logStartupInfo];
		[self logMessage:@"HJSDebugCenter initialized"];

		_monitoredLogs = [NSMutableDictionary new];
    }
    return self;
}

- (void)dealloc {
	[self logMessage:@"HJSDebugCenter dealloc called."];
}

- (void)terminateLogging {
	[self logMessage:@"Logging terminated"];
	if (_logFile) {
		asl_remove_log_file(_aslClient, _logFile.fileDescriptor);
		[_logFile closeFile];
		_logFile = nil;
	}
	asl_close(_aslClient);
	_aslClient = NULL;
}

#pragma mark internals

- (void)logMessage:(NSString *)message level:(HJSLogLevel)level skipBreak:(BOOL)skipBreak {
	asl_log(_aslClient, NULL, level, "%s", [message UTF8String]);
	if (!skipBreak && level == HJSLogLevelCritical) {
		[self debugBreakNoLogging];
	}
}

/// Build a settings file from scratch, based on compile-time defines active.
- (void)createSettings {
	[self logFormattedString:@"Creating new settings file at %@", _settingsFileURL];

	_settings = [NSMutableDictionary new];
	// Release builds log warnings & up, no ad-hoc debugging, and no debug break
	[self setLogLevel:HJSLogLevelWarning];
	[self setAdHocDebugging:NO];
	[self setDebugBreakEnabled:NO];
#if BETA
	// Beta cranks the level down to Info, and turns on ad-hoc debugging. DebugBreak is still disabled.
	[self setAdHocDebugging:YES];
	[self setLogLevel:HJSLogLevelInfo];
	[self logMessage:@"Beta defined, ad-hoc debugging activated."];
#endif
#if DEBUG
	// Debug cranks the level down to Info and turns on ad-hoc & debugBreak. Note this overrrides BETA if
	// both are defined
	[self setAdHocDebugging:YES];
	[self setDebugBreakEnabled:YES];
	[self setLogLevel:HJSLogLevelInfo];
	[self logMessage:@"Debug defined, ad-hoc debugging & debugBreak() activated."];
#endif
	// save the settings we just created
	[self saveSettings];
}

/// Dumps some useful information into the log
- (void)logStartupInfo {
	[self logMessage:@"=========================="];

	NSDictionary * mainBundleInfo = [[NSBundle mainBundle] infoDictionary];
	[self logFormattedString:@"%@ version: %@, build: %@",
	 [mainBundleInfo objectForKey:@"CFBundleExecutable"],
	 [mainBundleInfo objectForKey:@"CFBundleShortVersionString"],
	 [mainBundleInfo objectForKey:@"CFBundleVersion"]
	 ];
	NSDictionary * frameworkBundleInfo = [[NSBundle bundleForClass:self.class] infoDictionary];
	[self logFormattedString:@"HJSDebug version: %@, build: %@",
	 [frameworkBundleInfo objectForKey:@"CFBundleShortVersionString"],
	 [frameworkBundleInfo objectForKey:@"CFBundleVersion"]
	 ];

	if (self.adHocDebugging) {
		[self logMessage:@"Ad-hoc debugging is on."];
	}
	else {
		[self logMessage:@"Ad-hoc debugging is off."];
	}
	if (self.debuggerAttached) {
		[self logMessage:@"Debugger is attached."];
	}
	else {
		[self logMessage:@"No debugger is attached, debugBreak will not be active."];
	}
#if DEBUG
	[self logMessage:@"DEBUG is defined in build."];
	if (self.debugBreakEnabled) {
		[self logMessage:@"Debug Break is enabled."];
	}
	else {
		[self logMessage:@"Debug Break is off in the options."];
	}
#endif
#if BETA
	[self logMessage:@"BETA is defined in build."];
#endif

	[self logMessage:@"=========================="];
}

@end
