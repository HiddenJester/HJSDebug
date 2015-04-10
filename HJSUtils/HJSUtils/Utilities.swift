//
//  Utilities.swift
//  HJSKit
//
//  Created by Timothy Sanders on 10/15/14.
//  Copyright (c) 2014 HiddenJester Software. All rights reserved.
//

import Foundation

import HJSDebug

/// Handy to keep around. Use existingCenter because we're part of HJSKit and shouldn't create a new center.
let debug = HJSDebugCenter.existingCenter()

/**
	CGSize implementation of CGRectInset-like logic

	:param: size The original size to inset.
	:param: dx The amount to shrink the width. Negative values grow the width.
	:param: dy The amount to shrink the height. Negative values grow the height.
	
	:returns: An inset CGSize
*/
public func CGSizeInset(size: CGSize, dx: CGFloat, dy: CGFloat) -> CGSize {
	return CGSizeMake(size.width - dx, size.height - dy)
}

/**
Simple function that takes an optional NSNotificationCenter observer object, removes it from the default center,
and then nils the optional reference.

:param: observerRef The observer, passed by reference so it can be niled.

:param: logNilValue A bool indicating whether a critical log should be made if observerRef is true. Defaults to
	true if omitted.
*/
public func cleanupOptionalObserver(inout observerRef: NSObjectProtocol?,  logNilValue: Bool = true) {
	if let observer = observerRef {
		NSNotificationCenter.defaultCenter().removeObserver(observer)
		observerRef = nil
	}
	else if logNilValue {
		debug.logAtLevel(.Critical, message: "Should have had an observer here.")
	}
}
