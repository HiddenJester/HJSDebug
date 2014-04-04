//
//  HJSDebug.h
//  Combat Imp
//
//  Created by Timothy Sanders on 4/3/14.
//
//

@interface HJSDebug : NSObject

+ (void)debugBreak;
+ (void)logError:(NSError*)error atDepth:(int)depth;

@end

