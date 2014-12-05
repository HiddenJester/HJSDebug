//
//  KeepViewAboveKeyboard.swift
//  HJSExtension
//
//  Created by Timothy Sanders on 2014-12-04.
//  Copyright (c) 2014 HIddenJester Software. All rights reserved.
// This work is licensed under the Creative Commons Attribution-ShareAlike 4.0
// International License. To view a copy of this license, visit
// http://creativecommons.org/licenses/by-sa/4.0/deed.en_US.//

import UIKit

/**
:brief: Adjusts the center of a view to keep a child view above the keyboard.

Takes a a view to adjust as the keyboard needs, and then you can specify which child view needs to be right above the 
top of the keyboard. The widget will process the keyboard notifications and do the right tricks. You can change
targetView and the adjustment will update as needed. It also handles ongoing tweaks like turning the iOS 8 predictive
text bar on/off can change the amount of adjustment that is needed.

Lastly, it manages the issue where the keyboardWilChangeFrame notification is supposed to store a
UIViewAnimationCurve constant but sometimes returns 7, which is really a bitmask of a few bits in
UIViewAnimationOptions. It checks if the value really is a valid UIViewAnimationCurve. If it isn't, but the
rawValue was 7 then it will go ahead and log a debug message to that effect and set the curveType to .EaseInEaseOut.
If the value was some *OTHER* thing it logs a critical message about having an unknown value and sets the curveType
to .EaseInEaseOut anyway. So curveType will ALWAYS be legal, even if the behavior of this is changed in the future.

:warning: 
This class is designed for a simple UIView that just needs to be adjusted in parent space. If you have a
UIScrollView than you probably also want to take contentOffset into account which this class does not.

Objective C usage (called from a UIViewController):

:code:
KeepViewAboveKeyboard * _keyboardWatcher = [[KeepViewAboveKeyboard alloc] initWithView:self.view];
_keyboardWatcher.targetView = _detailField;
*/
@objc public class KeepViewAboveKeyboard : NSObject {
	/// The view that we are keeping just above the keyboard. Changing this while the keyboard is up can update
	/// the offset. You can set this from textFieldDidBeginEditing to make sure the correct field is above the keyboard.
	@objc public weak var targetView: UIView? = nil {
		didSet {
			updateScrollForViewAndRect()
		}
	}

	/// The view is that is adjusted as needed. Note that this is for views that are not UIScrollViews as we are
	/// simply manipulating the view's center property with no adjustments for content offsets.
	private weak var adjustedView : UIView?

	/// The keyboard rect (in local space), as it changes
	private var keyboardRect = CGRectZero

	/// All of the values for the keyboard animation, cached so we can reuse if the code changes targetView
	private var animDuration = NSTimeInterval(0)
	private var curveType: UIViewAnimationCurve = .Linear
	private var animOptions: UIViewAnimationOptions = .TransitionNone

	/// As we move adjustedViews center view we track the amount we've moved it here
	private var currentAdjustment = CGFloat(0)
	/// The UIKeyboardWillChangeFrameNotification observer
	private let keyboardObserver : NSObjectProtocol!

	/// Handy to keep around. Use existingCenter because we're part of HJSKit and shouldn't create a new center.
	private let debug = HJSDebugCenter.existingCenter()

	//MARK: Lifecycle
	/**
	Initializes a new KeepViewAboveKeyboard object.

	:param: view The view that will be adjusted as needed to keep targetView onscreen above the keyboard
	:returns: A KeepViewAboveKeyboard object.
	*/
	@objc public init(view: UIView) {
		adjustedView = view

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
		debug.logAtLevel(.Debug, message: "KeepViewAboveKeyboard deinit called.")
		NSNotificationCenter.defaultCenter().removeObserver(keyboardObserver)
		zeroScroll()
	}

	private func processKeyboardWillChangeFrame(note: NSNotification) {
		// Bail if we're not configured to do anything useful.
		if hasInvalidState() {
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
				// Convert the rect into scrolleeView local space. hasInvalidState tested for adjustedView up above
				// so the unwrap is safe.
				keyboardRect = adjustedView!.convertRect(keyboardRect, fromView: nil)
			}
		}
		updateScrollForViewAndRect()
	}

	/// This function does the work of the class. We call it both when a keyboard notification occurs and when
	/// targetView is changed. In the latter case we'll make an animation that uses the same values we received
	/// in the last keyboard update.
	private func updateScrollForViewAndRect() {
		// Bail if we're not configured to do anything useful.
		if hasInvalidState() || keyboardRect.size.height == 0 {
			return
		}
		// At this point it's safe to force-unwrap targetView, adjustedView, and targetView.superview (because
		// we know at the very least that adjustedView is a superView of targetView). If none of those worked
		// hasInvalidState would have returned true.

		// TargetView may not be a direct child of adjustedView, just somewhere in the child hierarchy. So in order to
		// do the math we need to adjust targetView's origin into scrolleeView's local space.
		let targetFrame = targetView!.superview!.convertRect(targetView!.frame, toView:adjustedView!)
		let targetViewBottomY = targetFrame.origin.y + targetFrame.size.height
		let verticalDelta = keyboardRect.origin.y - targetViewBottomY;

		// If targetViewBottomY is inside keyboardRect then we need to move
		if verticalDelta < 0.0 {
			UIView.animateWithDuration(animDuration,
				delay: 0,
				options: animOptions,
				animations: { () -> Void in
					self.adjustedView!.center =
						CGPointMake(self.adjustedView!.center.x, self.adjustedView!.center.y + verticalDelta);
				},
				completion: nil)
			currentAdjustment += verticalDelta
		}
		// TargetViewBottomY is not inside keyboardRect. If we have previously adjusted we should spend some/all of it.
		else if currentAdjustment < 0.0 {
			// If the currentAdjustment is less than -verticalDelta we want to roll off vertDelta's worth
			if currentAdjustment < -verticalDelta {
				UIView.animateWithDuration(animDuration,
					delay: 0,
					options: animOptions,
					animations: { () -> Void in
						self.adjustedView!.center =
							CGPointMake(self.adjustedView!.center.x, self.adjustedView!.center.y + verticalDelta);
					},
					completion: nil)
				currentAdjustment += verticalDelta
			}
			// currentAdjustement is less than -verticalDelta, we can zero it out now.
			else {
				zeroScroll()
			}
		}
	}

	/// Clear out currentAdjustment. If it still had a value left animate it away.
	private func zeroScroll() {
		if currentAdjustment < 0.0 {
			if let view = adjustedView? {
				UIView.animateWithDuration(animDuration,
					delay: 0,
					options: animOptions,
					animations: { () -> Void in
						view.center = CGPointMake(view.center.x, view.center.y - self.currentAdjustment);
					},
					completion: nil)
			}
			currentAdjustment = 0
		}
	}

	/**
	Test that we have both weak view references and that targetView is a child of adjustedView. If any of those
	are false then we probably just want to skip whatever it was we were about to try.
	
	:returns: true if something is wrong, false if we can proceed with the math
	*/
	private func hasInvalidState() -> Bool {
		// No point if either of our weak view refs have gone away. Also if targetView isn't a child of adjustedView
		// then the math won't work. Note the third test can safely unwrap targetView because if it was
		// nil then the second test would have triggered and we'd short-circuit
		if  adjustedView? == nil || targetView? == nil || !targetView!.isDescendantOfView(adjustedView!) {
			debug.logMessage("KeepViewAboveKeyboard is installed but has no work to do.")
			return true
		}
		return false
	}
}

