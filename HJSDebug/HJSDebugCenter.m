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

- (void)logWithFormatString:(NSString *)formatString, ... {
    va_list args;
    va_start(args, formatString);

	[self logMessage:[[NSString alloc] initWithFormat:formatString arguments:args] level:HJSLogLevelInfo skipBreak:YES];

	va_end(args);
}

- (void)logAtLevel:(HJSLogLevel)level formatString:(NSString *)formatString, ... {
    va_list args;
    va_start(args, formatString);
	
	[self logMessage:[[NSString alloc] initWithFormat:formatString arguments:args] level:level skipBreak:NO];
	
    va_end(args);
}


- (void)logError:(NSError*)error depth:(int)depth {
	NSMutableString * tempLeader = [[NSMutableString alloc] initWithString:@""];
	
	for (int i = 0; i < depth; ++i) {
		[tempLeader appendString:@"    "];
	}
	NSString * leader = [tempLeader copy];
	
	[self logWithFormatString:@"%@Logging error at depth %d", leader, depth];
    if ([error.userInfo objectForKey:NSDetailedErrorsKey]) {
        for (NSError* subError in [error.userInfo objectForKey:NSDetailedErrorsKey]) {
            [self logError:subError depth:depth + 1];
        }
    }
    else {
        [self logWithFormatString:@"%@Error %ld %@ userInfo:", leader, (long)error.code, error.localizedDescription];
		[error.userInfo enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
			[self logWithFormatString:@"%@ key:%@", leader, key];
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

static NSInteger logDelayCount = 0;

- (void)mailLogWithExplanation:(NSString *)explanation {
	if (![self canSendMail]) {
		[self logWithFormatString:@"Mail is not enabled, log cannot be sent."];
		return;
	}

	MFMailComposeViewController * mailController = [MFMailComposeViewController new];
	if (!_mailComposeDelegate) {
		_mailComposeDelegate = [HJSDebugMailComposeDelegate new];
	}
	mailController.mailComposeDelegate = _mailComposeDelegate;

	[mailController setSubject:@"Data issue with Combat Imp"];
	[mailController setToRecipients:@[@"bugs@hiddenjester.com"]];
	
	NSString * body = [NSString stringWithFormat:@"%@\n\n=== LOG FILE BEGINS ===\n%@=== LOG FILE ENDS ===", explanation, [self logContents]];
	[mailController setMessageBody:body isHTML:NO];
	
	if ([[[UIApplication sharedApplication] keyWindow] rootViewController]) {
		[[[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:mailController animated:YES completion:NULL];
		logDelayCount = 0;
	} else {
		++logDelayCount;
		if (logDelayCount > 10) {
			// Seriously? We're super-boned and we *can't even tell the user*. Abort.
			abort();
		}
		[self logWithFormatString:@"mailLog called before rootViewController is available, will retry in 1 second."];
		// Assume we're starting up and just try again in a second
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(NSEC_PER_SEC)),
					   dispatch_get_main_queue(),
					   ^{
						   [self mailLogWithExplanation:explanation];
					   });
	}
}

- (NSString *)logContents {
	NSError * error;
	NSString * log = [NSString stringWithContentsOfFile:_logFileURL.path encoding:NSUTF8StringEncoding error:&error];
	if (error) {
		[self logError:error depth:0];
	}
	return log;
}

# pragma mark Configuration Methods

- (void)saveSettings {
	[_settings writeToFile:_settingsFileURL.path atomically:YES];
}

- (void)displayControlPanel {
	HJSDebugCenterControlPanelViewController * panelController = [HJSDebugCenterControlPanelViewController new];
	NSArray * objects = [[NSBundle mainBundle] loadNibNamed:@"HJSDebugCenterControlPanel" owner:panelController options:nil];
	panelController.view = objects[0];
	
	[[[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:panelController animated:YES completion:NULL];
}

- (BOOL)canSendMail {
	// Could an option in the future to permanently disable mail
	return [MFMailComposeViewController canSendMail];
}

#pragma mark Lifecycle

- (id)init {
    NSError* error = nil;

	if (defaultCenter) {
		[self logAtLevel:HJSLogLevelCritical
			formatString:@"Don't create HJSDebugCenter objects, use HJSDebugCenter defaultCenter instead."];
		return nil;
	}

    self = [super init];
    if (self) {
		_client = asl_open(NULL, NULL, ASL_OPT_NO_DELAY | ASL_OPT_STDERR);
		
		// Put the log file in the application's cache folder
		NSArray * possibleURLs = [[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory
																		inDomains:NSUserDomainMask];
		_logFileURL = [NSURL URLWithString:logFilename relativeToURL:possibleURLs[0]];
		[[NSFileManager defaultManager] createFileAtPath:_logFileURL.path contents:nil attributes:nil];
		_logFile = [NSFileHandle fileHandleForWritingToURL:_logFileURL error:&error];
		if (!_logFile) {
			[self logError:error depth:0];
		} else {
			asl_add_log_file(_client, _logFile.fileDescriptor);
		}
		
		// Create or open the settings plist in the application's document directory
		possibleURLs = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
															  inDomains:NSUserDomainMask];
		_settingsFileURL = [NSURL URLWithString:settingsFilename relativeToURL:possibleURLs[0]];
		_settings = [[NSMutableDictionary alloc] initWithContentsOfFile:_settingsFileURL.path];
		if (!_settings) {
			_settings = [NSMutableDictionary new];
			[self setLogLevel:HJSLogLevelWarning];
			[self setAdHocDebugging:NO];
			[self saveSettings];
		} else {
			[self setLogLevel:[[_settings objectForKey:loggingLevelKey] integerValue]];
		}
		
#ifdef DEBUG
		[self setAdHocDebugging:YES];
		[self setLogLevel:HJSLogLevelDebug];
		[self saveSettings];
#endif
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

