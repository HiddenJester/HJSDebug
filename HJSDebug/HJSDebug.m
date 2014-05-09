//  Created by Timothy Sanders on 4/3/14.
//
//

#import "HJSDebug.h"

#include <asl.h>

// Runtime storage of the settings plist
static NSMutableDictionary * settings;
static NSString * settingsFilename;

static aslclient client;

static NSFileHandle * logFile;

@implementation HJSDebug

# pragma Debugging only methods

+ (void)debugBreak {
#if DEBUG
	raise(SIGTRAP);
#endif
}

#pragma mark Logging methods

+ (void)logWithFormatString:(NSString *)formatString, ... {
    va_list args;
    va_start(args, formatString);

	[HJSDebug logMessage:[[NSString alloc] initWithFormat:formatString arguments:args] level:HJSLogLevelInfo skipBreak:YES];

	va_end(args);
}

+ (void)logAtLevel:(HJSLogLevel)level formatString:(NSString *)formatString, ... {
    va_list args;
    va_start(args, formatString);
	
	[HJSDebug logMessage:[[NSString alloc] initWithFormat:formatString arguments:args] level:level skipBreak:NO];
	
    va_end(args);
}


+ (void)logError:(NSError*)error depth:(int)depth {
	NSMutableString * tempLeader = [[NSMutableString alloc] initWithString:@""];
	
	for (int i = 0; i < depth; ++i) {
		[tempLeader appendString:@"    "];
	}
	NSString * leader = [tempLeader copy];
	
	[HJSDebug logWithFormatString:@"%@Logging error at depth %d", leader, depth];
    if ([error.userInfo objectForKey:NSDetailedErrorsKey]) {
        for (NSError* subError in [error.userInfo objectForKey:NSDetailedErrorsKey]) {
            [self logError:subError depth:depth + 1];
        }
    }
    else {
        [HJSDebug logWithFormatString:@"%@Error %ld %@ userInfo:", leader, (long)error.code, error.localizedDescription];
		[error.userInfo enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
			[HJSDebug logWithFormatString:@"%@ key:%@", leader, key];
			NSArray * lines = [[obj description] componentsSeparatedByString:@"\\n"];
			for (NSString * line in lines) {
				NSString * output = [NSString stringWithFormat:@"%@   %@", leader, line];
				[HJSDebug logMessage:output level:HJSLogLevelCritical skipBreak:YES];
			}
		}];
		if (depth == 0) { // We're done logging, time to break
			[HJSDebug debugBreak];
		}
    }
}

+ (void)setLogLevel:(HJSLogLevel)level {
	NSNumber * loggingLevel = [NSNumber numberWithInteger:level];
	[settings setObject:loggingLevel forKey:loggingLevelKey];
	[settings writeToFile:settingsFilename atomically:YES];
	asl_set_filter(client, ASL_FILTER_MASK_UPTO(level));
	if (logFile) {
		asl_set_output_file_filter(client, logFile.fileDescriptor, ASL_FILTER_MASK_UPTO(level));
	}
}

#pragma mark Lifecycle

static NSString * loggingLevelKey = @"LoggingLevel";

+ (void)initialize {
	client = asl_open(NULL, NULL, ASL_OPT_NO_DELAY | ASL_OPT_STDERR);

	NSArray * possibleURLs = [[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask];
	NSURL * logURL = [NSURL URLWithString:@"HJSDebugLog.txt" relativeToURL:possibleURLs[0]];
	[[NSFileManager defaultManager] createFileAtPath:logURL.path contents:nil attributes:nil];
    NSError* error = nil;
	logFile = [NSFileHandle fileHandleForWritingToURL:logURL error:&error];
	
	if (!logFile) {
		[HJSDebug logError:error depth:0];
	} else {
		asl_add_log_file(client, logFile.fileDescriptor);
	}
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
														 NSUserDomainMask, YES);
	settingsFilename = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"HJSDebugSettings.plist"];
	
	settings = [[NSMutableDictionary alloc] initWithContentsOfFile:settingsFilename];
	if (!settings) {
		settings = [NSMutableDictionary new];
#ifdef DEBUG
		[HJSDebug setLogLevel:HJSLogLevelInfo];
#else
		[HJSDebug setLogLevel:HJSLogLevelCritical];
#endif
	} else {
		[HJSDebug setLogLevel:[[settings objectForKey:loggingLevelKey] integerValue]];
	}
}

+ (void)terminateLogging {
	if (logFile) {
		asl_remove_log_file(client, logFile.fileDescriptor);
		[logFile closeFile];
		logFile = nil;
	}
	asl_close(client);
	client = NULL;
	
	
}

#pragma mark internals

+ (void)logMessage:(NSString *)message level:(HJSLogLevel)level skipBreak:(BOOL)skipBreak {
	asl_log(client, NULL, level, "%s", [message UTF8String]);
	if (!skipBreak && level == HJSLogLevelCritical) {
		[HJSDebug debugBreak];
	}
}

@end

