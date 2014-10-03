//
//  HJSDebug.swift
//
//  Created by Timothy Sanders on 9/29/14.
//  Copyright (c) 2014 HiddenJester Software. All rights reserved.
//

import Foundation
import HJSKit

// The Objective-C API has the nifty NS_FORMAT_FUNCTION macros that let you call logWithFormatString like NSLog
// Those do not convert nicely to Swift style variadic args, so here in a Swift extension we declare Swift wrappers
// around the CVarArgType ugliness. Now a call like debugCenter.logWithFormatString("Testing %d", 45) will go through
// here and hit the va_list version I added in Objective-C.

extension HJSDebugCenter {
	public func logWithFormatString(format: String, _ args: CVarArgType...) {
		self.logWithFormatString(format, args:getVaList(args))
	}

	public func logAtLevel(level: HJSLogLevel, format: String, _ args: CVarArgType...) {
		self.logAtLevel(level, formatString: format, args:getVaList(args))
	}
}
