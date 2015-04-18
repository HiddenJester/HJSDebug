//
//  BaseViewAboveKeyboard.swift
//  HJSExtension
//
//  Created by Timothy Sanders on 2014-12-07.
//  Copyright (c) 2014 HiddenJester Software.
//	This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
//	See http://creativecommons.org/licenses/by-nc-sa/4.0/

import UIKit

import HJSDebug
import HJSUtils			// Uses cleanupOptionalObserver

let debug = HJSDebugCenter.existingCenter()

/**
A common base class for managing keyboard view changes.

Regardless of what action wants to be taken there is a fair amount of common code around moving views when the keyboard
appears. This common base class takes a view (adjustee) that is to be manipulated and watches the keyboard
notification. It tracks where the keyboard is in the view's local space and calls an overridable function to do
something in response.

This also manages the issue where the keyboardWilChangeFrame notification is supposed to store a
UIViewAnimationCurve constant but sometimes returns 7, which is really a bitmask of a few bits in
UIViewAnimationOptions. It checks if the value really is a valid UIViewAnimationCurve. If it isn't, but the
rawValue was 7 then it will go ahead and log a debug message to that effect and set the curveType to .EaseInEaseOut.
If the value was some *OTHER* thing it logs a critical message about having an unknown value and sets the curveType
to .EaseInEaseOut anyway. So curveType will ALWAYS be legal, even if the other non-documented values are received
in the future.

Child classes need to override update() to do whatever adjustments they provide. They should also override
zeroAdjustments which will be called when the adjustment needs to be entirely removed.
*/

@objc public class BaseViewAboveKeyboard : NSObject {
	/// You can provide a block that will be called when each adjustment is made. This will be called when the
	/// adjustment animation *starts*.
	@objc public var adjustmentBlock: (() -> Void)?

	/// This block is called whenever an adjustment animation *finishes*.
	@objc public var completionBlock: (() -> Void)?

	/// Padding adds a gap between the keyboard and the target view.
	@objc public var padding = CGFloat(0)

	// MARK: Internal variables
	// All of the following variables are not private so child classes can access them. But they also aren't public
	// so they aren't visible outside of HJSKeyboardHelpers.

	/// The view is that is adjusted as needed. Note that this is weak therefore it must be optional.
	@objc weak var adjustee : UIView? {
		willSet {
			zeroAdjustments()
		}
		didSet {
			update()
		}
	}

	/// The keyboard rect (in adjustee local space), as it changes.
	var keyboardRect = CGRectZero

	/// All of the values for the keyboard animation, cached so we can reuse if the code changes adjustee.
	var animDuration = NSTimeInterval(0)
	var curveType: UIViewAnimationCurve = .Linear
	var animOptions: UIViewAnimationOptions = .TransitionNone

	/// The UIKeyboardWillChangeFrameNotification observer
	private var keyboardObserver : NSObjectProtocol?

	// MARK: Functions to override
	/**
	This function does the work of the class. We call it both when a keyboard notification occurs and when
	adjustee is changed. In the latter case we'll make an animation that uses the same values we received
	in the last keyboard update.

	:Warning: The child classes need to also call adjustmentBlock and completionBlock where appropriate.
	*/
	func update() {
		debug.logAtLevel(.Critical,
			message: "Don't call BaseViewAboveKeyboard functions, override update in the child.")
	}

	/**
	This function must be overridden by a child. It should roll off any adjustments made to adjustee.

	:Warning: The child classes need to also call adjustmentBlock and completionBlock where appropriate.
	*/
	 func zeroAdjustments() {
		debug.logAtLevel(.Critical,
			message: "Don't call BaseViewAboveKeyboard functions, override zeroAdjustments in the child.")
	}

	// MARK: Lifecycle
	/**
	Initializes a new KeepViewAboveKeyboard object.

	:param: view The view that will be adjusted as needed to keep onscreen above the keyboard
	:returns: A BaseViewAboveKeyboard object.
	*/
	@objc public init(view: UIView) {
		adjustee = view

		super.init()

		keyboardObserver = NSNotificationCenter.defaultCenter().addObserverForName(
			UIKeyboardWillChangeFrameNotification,
			object: nil,
			queue: nil) { [weak self] (note) -> Void in
				self?.processKeyboardWillChangeFrame(note)
		}
	}

	deinit {
		debug.logAtLevel(.Debug, message: "BaseViewAboveKeyboard deinit called.")
		zeroAdjustments()
		cleanupOptionalObserver(&keyboardObserver)
	}

	// MARK: Internals
	private func processKeyboardWillChangeFrame(note: NSNotification) {
		debug.logAtLevel(.Debug, message: "---Keyboard Will Change Frame notification.---")
		// Pull useful info out of the notification and keep for future use.
		if let adjustee = adjustee, userInfo = note.userInfo as? [NSObject : NSValue] {
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
				// Convert the rect into adjustee local space.
				keyboardRect = adjustee.convertRect(keyboardRect, fromView: nil)
				debug.logAtLevel(.Debug, message: "KeyboardRect: \(keyboardRect)")
			}

			update()
		}
	}
}

