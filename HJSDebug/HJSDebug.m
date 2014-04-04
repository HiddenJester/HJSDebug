//
//  HJSDebug.m
//  Combat Imp
//
//  Created by Timothy Sanders on 4/3/14.
//
//

#import "HJSDebug.h"

@implementation HJSDebug

#pragma mark Logging methods

+ (void)debugBreak {
#if DEBUG
	raise(SIGTRAP);
#endif
}

+ (void)logError:(NSError*)error atDepth:(int)depth {
    NSLog(@"Logging error at depth %d", depth);
    if ([error.userInfo objectForKey:NSDetailedErrorsKey]) {
        for (NSError* subError in [error.userInfo objectForKey:NSDetailedErrorsKey]) {
            [self logError:subError atDepth:depth + 1];
        }
    }
    else {
        NSLog(@"Error %ld says %@, localized: %@\n---\n", (long)error.code, error.userInfo, error.localizedDescription);
    }
}

@end

