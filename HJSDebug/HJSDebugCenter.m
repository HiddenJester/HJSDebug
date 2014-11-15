//  Created by Timothy Sanders on 4/3/14.
//
//

#import "HJSDebugCenter.h"

#include <asl.h>

#import <MessageUI/MessageUI.h>

#import "HJSDebugMailComposeDelegate.h"
#import "HJSDebugCenterControlPanelViewController.h"

static NSString * logFilename = @"HJSDebugLog.txt";
static NSString * settingsFilename = @"HJSDebugSettings.plist";

static NSString * loggingLevelKey = @"LoggingLevel";
static NSString * adHocDebuggingKey = @"adHocDebugging";

static HJSDebugCenter * defaultCenter;

@implementation HJSDebugCenter {
	// Runtime storage of the settings plist
	NSMutableDictionary * _settings;
	NSURL * _settingsFileURL;
	
	// Logging bits
	aslclient _client;
	NSFileHandle * _logFile;
	NSURL * _logFileURL;

	HJSDebugMailComposeDelegate * _mailComposeDelegate;
}

+ (HJSDebugCenter *)defaultCenter {
	static dispatch_once_t onceToken;
	
	dispatch_once(&onceToken, ^{
		defaultCenter = [HJSDebugCenter new];
	});
	return defaultCenter;
}

#pragma mark Properties

- (void)setLogLevel:(HJSLogLevel)level {
	NSNumber * loggingLevel = [NSNumber numberWithInteger:level];
	[_settings setObject:loggingLevel forKey:loggingLevelKey];
	asl_set_filter(_client, ASL_FILTER_MASK_UPTO(level));
	if (_logFile) {
		asl_set_output_file_filter(_client, _logFile.fileDescriptor, ASL_FILTER_MASK_UPTO(level));
	}
}

- (HJSLogLevel)logLevel {
	return [[_settings objectForKey:loggingLevelKey] integerValue];
}

- (void)setAdHocDebugging:(BOOL)adHocDebugging {
	NSNumber * adHocFlag = [NSNumber numberWithBool:adHocDebugging];
	[_settings setObject:adHocFlag forKey:adHocDebuggingKey];
}

- (BOOL)adHocDebugging {
	return [[_settings objectForKey:adHocDebuggingKey] boolValue];
}

# pragma mark Debug only methods

- (void)debugBreak {
#if DEBUG
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
			[self debugBreak];
		}
    }
}

#pragma mark Mail Log methods

- (BOOL)presentMailLogWithExplanation:(NSString *)explanation
							  subject:(NSString *)subject
				   fromViewController:(UIViewController *)presenter {
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
	
	NSString * body = [NSString stringWithFormat:@"%@\n\n=== LOG FILE BEGINS ===\n%@=== LOG FILE ENDS ===",
					   explanation,
					   [self logContents]];
	[mailController setMessageBody:body isHTML:NO];

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

- (NSString *)logContents {
	NSError * __autoreleasing error;
	NSString * log = [NSString stringWithContentsOfFile:_logFileURL.path encoding:NSUTF8StringEncoding error:&error];
	if (error) {
		[self logError:error];
	}
	return log;
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

    self = [super init];
    if (self) {
		_client = asl_open(NULL, NULL, ASL_OPT_NO_DELAY | ASL_OPT_STDERR);


		NSError * __autoreleasing error;
		// Put the log file in the application's cache folder
		_logFileURL = [[NSFileManager defaultManager] URLForDirectory:NSCachesDirectory
															 inDomain:NSUserDomainMask
													appropriateForURL:nil
															   create:YES
																error:&error];
		if (error) {
			[[HJSDebugCenter defaultCenter] logError:error];
		} else {
			_logFileURL = [_logFileURL URLByAppendingPathComponent:logFilename];
		}

		[[NSFileManager defaultManager] createFileAtPath:_logFileURL.path contents:nil attributes:nil];
		_logFile = [NSFileHandle fileHandleForWritingToURL:_logFileURL error:&error];
		if (!_logFile) {
			[self logError:error];
		} else {
			asl_add_log_file(_client, _logFile.fileDescriptor);
		}



		_settingsFileURL = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
																  inDomain:NSUserDomainMask
														 appropriateForURL:nil
																	create:YES
																	 error:&error];
		if (error) {
			[[HJSDebugCenter defaultCenter] logError:error];
		} else {
			_settingsFileURL = [_settingsFileURL URLByAppendingPathComponent:settingsFilename];
		}
		_settings = [[NSDictionary dictionaryWithContentsOfURL:_settingsFileURL] mutableCopy];
		if (!_settings) {
			_settings = [NSMutableDictionary new];
			[self setLogLevel:HJSLogLevelWarning];
			[self setAdHocDebugging:NO];
#if BETA
			[self setAdHocDebugging:YES];
			[self setLogLevel:HJSLogLevelInfo];
			[self logAtLevel:HJSLogLevelInfo formatString:@"Beta defined, ad-hoc debugging activated."];
			[self saveSettings];
#endif
			[self saveSettings];
		} else {
			[self setLogLevel:[[_settings objectForKey:loggingLevelKey] integerValue]];
		}
		
#if DEBUG
		[self setAdHocDebugging:YES];
		[self setLogLevel:HJSLogLevelDebug];
		[self saveSettings];
		[self logMessage:@"Debug build with ad-hoc debugging & debugBreak()."];
#endif
		NSDictionary * mainBundleInfo = [[NSBundle mainBundle] infoDictionary];
		[self logAtLevel:HJSLogLevelInfo formatString:@"App version: %@, build: %@",
		 [mainBundleInfo objectForKey:@"CFBundleShortVersionString"],
		 [mainBundleInfo objectForKey:@"CFBundleVersion"]
		 ];
#if HJS_FRAMEWORK_BUILD
		NSDictionary * frameworkBundleInfo = [[NSBundle bundleForClass:self.class] infoDictionary];
		[self logWithFormatString:@"HJSKit version: %@, build: %@",
		 [frameworkBundleInfo objectForKey:@"CFBundleShortVersionString"],
		 [frameworkBundleInfo objectForKey:@"CFBundleVersion"]
		 ];
#else
		[self logMessage:@"HJSKit not built from framework and has no separate version number."];
#endif
		[self logMessage:@"HJSDebugCenter initialized"];
		[self logMessage:@"=========================="];
    }
    return self;
}

- (void)terminateLogging {
	if (_logFile) {
		asl_remove_log_file(_client, _logFile.fileDescriptor);
		[_logFile closeFile];
		_logFile = nil;
	}
	asl_close(_client);
	_client = NULL;
}

#pragma mark internals

- (void)logMessage:(NSString *)message level:(HJSLogLevel)level skipBreak:(BOOL)skipBreak {
	asl_log(_client, NULL, level, "%s", [message UTF8String]);
	if (!skipBreak && level == HJSLogLevelCritical) {
		[self debugBreak];
	}
}

@end
