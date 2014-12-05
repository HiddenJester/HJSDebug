//
//  HJSKitKeepViewAboveKeyboard.swift
//  HJSExtension
//
//  Created by Timothy Sanders on 2014-12-04.
//  Copyright (c) 2014 HIddenJester Software. All rights reserved.
//

import UIKit

/// A simple widget that you can create, feed it a view to scroll as the keyboard needs, and then you can specify
/// which child view needs to be right above the top. The widget will process the keyboard notifications and do the
/// right tricks. You can change the target view and the scrolled offset will adjust as needed.
@objc public class HJSKitKeepViewAboveKeyboard : NSObject {
	/// The controller whose view is scrolled as needed. Note that this is for views that are not UIScrollViews
	private let managedViewController : UIViewController
	/// The view that we are keeping just above the keyboard
	@objc public var targetView: UIView? {
		didSet {
			updateScrollForViewAndRect()
		}
	}
	/// The keyboard rect (in local space), as it changes
	private var keyboardRect = CGRectZero
	/// All of the values for the keyboard animation, cached so we can reuse if the code changes targetView
	var animDuration = NSTimeInterval(0)
	var curveType: UIViewAnimationCurve = .Linear
	var animOptions: UIViewAnimationOptions = .TransitionNone

	/// As we scroll managedViewController's view we track the amount we've scrolled here
	private var accumulatedScroll = CGFloat(0)
	/// The UIKeyboardWillChangeFrameNotification observer
	private let keyboardObserver : NSObjectProtocol!

	//MARK: Lifecycle
	@objc public init(managedVC: UIViewController) {
		managedViewController = managedVC
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
		NSNotificationCenter.defaultCenter().removeObserver(keyboardObserver)
		zeroScroll()
	}

	private func processKeyboardWillChangeFrame(note: NSNotification) {
		// Pull useful info out of the notification.
		if let userInfo = note.userInfo as? [NSObject : NSValue]{
			// Get the duration of the animation.
			if let noteValue = userInfo[UIKeyboardAnimationDurationUserInfoKey] {
				noteValue.getValue(&animDuration)
			}

			// Get the curve of the animation and map it into animOptions
			if let noteValue = userInfo[UIKeyboardAnimationCurveUserInfoKey] {
				// Except … the API claims that this what it did, but iOS 7 (and 8) can return a value that isn't
				// legal (7). So instead we have bitshift up 16 to convert it to a UIViewAnimationOptions bitmask. 
				// So, TRY to do the right thing and log if we get an illegal value before trying to use it.
				var rawCurveValue = Int(0)
				noteValue.getValue(&rawCurveValue)
				if let tempCurve = UIViewAnimationCurve(rawValue: rawCurveValue) {
					curveType = tempCurve
				}
				else {
					// Screw it, this is a hack no matter how you slice it. If we indeed get 7 then just take it.
					if rawCurveValue == 7 {
						HJSDebugCenter.existingCenter().logAtLevel(.Debug,
							message: "Getting the stupid 7 for a keyboard anim curve.")
					}
					else {
						HJSDebugCenter.existingCenter().logAtLevel(.Critical,
							message: "Unknown curve value \(rawCurveValue) for a keyboard anim curve.")
					}
					curveType = .EaseInOut
				}

				switch curveType {
				case .EaseIn:
					animOptions = .CurveEaseIn

				case .EaseInOut:
					animOptions = .CurveEaseInOut

				case .EaseOut:
					animOptions = .CurveEaseOut

				case .Linear:
					animOptions = .CurveLinear
				}
			}

			// Get where the keyboard will end up.
			if let noteValue = userInfo[UIKeyboardFrameEndUserInfoKey] {
				noteValue.getValue(&keyboardRect)
				// Convert the rect into scrolleeView local space
				keyboardRect = managedViewController.view.convertRect(keyboardRect, fromView: nil)
			}
		}
		updateScrollForViewAndRect()
	}

	private func updateScrollForViewAndRect() {
		let scrolleeView = managedViewController.view
		// All of this only works if A ) we have a target view and B ) said targetView has a superview
		if targetView == nil || targetView?.superview == nil {
			HJSDebugCenter.existingCenter().logAtLevel(.Critical,
				message: "Can't process keyboard change notification without a targetView & superview.")
		}
		// Also if we don't have a keyboardRect we can't reasonably do the math.
		if keyboardRect.size.height == 0 {
			return
		}

		// targetView may not be a direct child of scrolleeView, just somewhere in the child hierarchy. So in order to
		// do the math we need to adjust targetView's origin into scrolleeView's local space.

		// We tested for targetView && targetView.superview above so this is safe.
		let targetFrameInScrollee = targetView!.superview!.convertRect(targetView!.frame, toView:scrolleeView)

		let targetViewBottomY = targetFrameInScrollee.origin.y + targetFrameInScrollee.size.height
		let verticalDelta = keyboardRect.origin.y - targetViewBottomY;

		// If the bottom is inside the rect then we need to move
		if verticalDelta < 0.0 {
			UIView.animateWithDuration(animDuration,
				delay: 0,
				options: animOptions,
				animations: { () -> Void in
					scrolleeView.center = CGPointMake(scrolleeView.center.x, scrolleeView.center.y + verticalDelta);
				},
				completion: nil)
			accumulatedScroll += verticalDelta
		}
		// The bottom is not inside the new rect. If we have accumulated scroll we should spend some/all of it.
		else if accumulatedScroll < 0.0 {
			// If the cumulative scroll is less than verticalDelta we want to roll off vertDelta's worth
			if accumulatedScroll < -verticalDelta {
				UIView.animateWithDuration(animDuration,
					delay: 0,
					options: animOptions,
					animations: { () -> Void in
						scrolleeView.center = CGPointMake(scrolleeView.center.x, scrolleeView.center.y + verticalDelta);
					},
					completion: nil)
				accumulatedScroll += verticalDelta
			}
			// We can zero out the cumulative scroll here
			else {
				zeroScroll()
			}
		}
	}

	private func zeroScroll() {
		if accumulatedScroll < 0.0 {
			let scrolleeView = managedViewController.view
			UIView.animateWithDuration(animDuration,
				delay: 0,
				options: animOptions,
				animations: { () -> Void in
					scrolleeView.center = CGPointMake(scrolleeView.center.x,
						scrolleeView.center.y - self.accumulatedScroll);
				},
				completion: nil)
			accumulatedScroll = 0
		}
	}
}

