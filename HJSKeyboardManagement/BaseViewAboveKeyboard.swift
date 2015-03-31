//
//  BaseViewAboveKeyboard.swift
//  HJSExtension
//
//  Created by Timothy Sanders on 2014-12-07.
//  Copyright (c) 2014 HIddenJester Software. All rights reserved.
// This work is licensed under the Creative Commons Attribution-ShareAlike 4.0
// International License. To view a copy of this license, visit
// http://creativecommons.org/licenses/by-sa/4.0/deed.en_US.//

import UIKit

/**
:brief: A common base class for managing keyboard view changes.

:description:
Regardless of what action wants to be taken there is a fair amount of common code around moving views when the
keyboard appears. This common base class takes a view that is to be manipulated and watches the keyboard notification.
It tracks where the keyboard is in the view's local space and calls an overridable function to do something in
response.

This also manages the issue where the keyboardWilChangeFrame notification is supposed to store a
UIViewAnimationCurve constant but sometimes returns 7, which is really a bitmask of a few bits in
UIViewAnimationOptions. It checks if the value really is a valid UIViewAnimationCurve. If it isn't, but the
rawValue was 7 then it will go ahead and log a debug message to that effect and set the curveType to .EaseInEaseOut.
If the value was some *OTHER* thing it logs a critical message about having an unknown value and sets the curveType
to .EaseInEaseOut anyway. So curveType will ALWAYS be legal, even if the behavior of this is changed in the future.

Child classes need to override update() to do whatever adjustments they provide. They should also override
zeroAdjustments which will be called when the adjustment needs to be entirely removed. They can optionally override
hasInvalidState which is used to determine whether everything is valid enough to run update, but if they override that
they should call super as well.
*/

@objc public class BaseViewAboveKeyboard : NSObject {
	/// You can provide a block that will be called when each adjustment is made. This will be called when the
	/// adjustment animation *starts*.
	@objc public var adjustmentBlock: (() -> Void)?

	/// This block is called whenever an adjustment animation *finishes*.
	@objc public var completionBlock: (() -> Void)?

	@objc public var padding = CGFloat(0)

	/// The view is that is adjusted as needed.
	weak var adjustee : UIView?
	/// The keyboard rect (in adjustee local space), as it changes
	var keyboardRect = CGRectZero


	/// All of the values for the keyboard animation, cached so we can reuse if the code changes targetView
	var animDuration = NSTimeInterval(0)
	var curveType: UIViewAnimationCurve = .Linear
	var animOptions: UIViewAnimationOptions = .TransitionNone

	/// The UIKeyboardWillChangeFrameNotification observer
	private let keyboardObserver : NSObjectProtocol!

	// MARK: Functions to override
	/**
	This function does the work of the class. We call it both when a keyboard notification occurs and when
	targetView is changed. In the latter case we'll make an animation that uses the same values we received
	in the last keyboard update.
	

	:warning: The child classes need to also call adjustmentBlock and completionBlock where appropriate
	*/
	func update() {
		debug.logAtLevel(.Critical,
			message: "Don't call BaseViewAboveKeyboard functions, override update in the child.")
	}

	func zeroAdjustments() {
		debug.logAtLevel(.Critical,
			message: "Don't call BaseViewAboveKeyboard functions, override zeroAdjustments in the child.")
	}

	func hasInvalidState() -> Bool {
		if adjustee? == nil || keyboardRect.size.height == 0 {
			debug.logMessage("BaseViewAboveKeyboard can't do any work.")
			return true
		}
		return false
	}

	//Convenience functions for calling the blocks
	func callAdjustmentBlock() {
		if let block = adjustmentBlock? {
			block()
		}
	}

	func callCompletionBlock() {
		if let block = completionBlock? {
			block()
		}
	}
	
	// MARK: Lifecycle
	/**
	Initializes a new KeepViewAboveKeyboard object.

	:param: view The view that will be adjusted as needed to keep targetView onscreen above the keyboard
	:returns: A KeepViewAboveKeyboard object.
	*/
	@objc public init(view: UIView) {
		adjustee = view

		super.init()

		keyboardObserver = NSNotificationCenter.defaultCenter().addObserverForName(
			UIKeyboardWillChangeFrameNotification,
			object: nil,
			queue: nil) { [weak self] (note) -> Void in
				if let blockSelf = self {
					blockSelf.processKeyboardWillChangeFrame(note)
				}
		}
	}

	deinit {
		zeroAdjustments()
		debug.logAtLevel(.Debug, message: "BaseViewAboveKeyboard deinit called.")
		// Can't use cleanupOptionalObserver because keyboardObserver is not optional.
		NSNotificationCenter.defaultCenter().removeObserver(keyboardObserver)
	}

	// MARK: Internals
	private func processKeyboardWillChangeFrame(note: NSNotification) {
		// Bail if we're not configured to do anything useful. Can't call hasInvalidState because it's OK
		// to not have a keyboardRect here.
		if adjustee? == nil {
			return
		}

		// Pull useful info out of the notification and keep for future use.
		if let userInfo = note.userInfo as? [NSObject : NSValue]{
			// Get the duration of the animation.
			if let noteValue = userInfo[UIKeyboardAnimationDurationUserInfoKey] {
				noteValue.getValue(&animDuration)
			}

			// Get the curve of the animation and map it into animOptions
			if let noteValue = userInfo[UIKeyboardAnimationCurveUserInfoKey] {
				// Except … the API claims that this what it did, but iOS 7 (and 8) can return a value that isn't
				// legal (7). We could bitshift it up 16 to convert it to a UIViewAnimationOptions bitmask, but
				// that's not a documented thing to do and I hate to write something that blindly assumes it will
				// work in the future.
				// So, TRY to do the right thing and if we get a garbage value juse use .EaseInOut. If we received
				// the bogus 7 then just log that at a debug level and if we got something else log that as .Critical
				// but go ahead and use .EaseInOut anyway. Basically force curveType to be *something* legal
				// regardless of what junk the API spewed.
				var rawCurveValue = Int(0)
				noteValue.getValue(&rawCurveValue)
				if let tempCurve = UIViewAnimationCurve(rawValue: rawCurveValue) {
					curveType = tempCurve
				}
				else {
					if rawCurveValue == 7 {
						debug.logAtLevel(.Debug, message: "Getting the stupid 7 for a keyboard anim curve.")
					}
					else {
						debug.logAtLevel(.Critical,
							message: "Unknown curve value \(rawCurveValue) for a keyboard anim curve.")
					}
					curveType = .EaseInOut
				}

				// Reset animOptions to a known value
				animOptions = .TransitionNone
				// And push in the curveType.
				switch curveType {
				case .EaseIn:
					animOptions |= .CurveEaseIn

				case .EaseInOut:
					animOptions |= .CurveEaseInOut

				case .EaseOut:
					animOptions |= .CurveEaseOut

				case .Linear:
					animOptions |= .CurveLinear
				}
			}

			// Get where the keyboard will end up.
			if let noteValue = userInfo[UIKeyboardFrameEndUserInfoKey] {
				noteValue.getValue(&keyboardRect)
				// Convert the rect into adjustee local space. hasInvalidState tested for adjustee up above
				// so the unwrap is safe.
				keyboardRect = adjustee!.convertRect(keyboardRect, fromView: nil)
			}
		}
		update()
	}
}

