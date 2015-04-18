//
//  SlideViewAboveKeyboard.swift
//  HJSExtension
//
//  Created by Timothy Sanders on 2014-12-04.
//  Copyright (c) 2014 HiddenJester Software.
//	This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
//	See http://creativecommons.org/licenses/by-nc-sa/4.0/

import UIKit

/**
A keyboard helper that adjusts a UIView (adjustee) to keep a specified child view (targetView) above the keyboard.
This class provides all of the functions of BaseViewAboveKeyboard.

:warning: This helper works by manipulating adjustee.center. If you are using Auto Layout to set the size of adjustee
	then you may have problems and should use a different approach. (Note that positioning adjustee *children* using
	Auto Layout is fine. But adjustee itself should be using auto resize mask. Top level UIViews are the intended
	target.

Objective C usage (called from a UIViewController):

	SlideViewAboveKeyboard * _keyboardWatcher = [[SlideViewAboveKeyboard alloc] initWithView:self.view];
	_keyboardWatcher.targetView = _detailField;
*/
@objc public class SlideViewAboveKeyboard : BaseViewAboveKeyboard {
	/// The view that we are keeping just above the keyboard. Changing this while the keyboard is up can update
	/// the offset. You can set this from textFieldDidBeginEditing to make sure the correct field is above the keyboard.
	@objc public weak var targetView: UIView? = nil {
		didSet {
			update()
		}
	}

	/// As we move adjustees center we track the amount we've moved it here
	private var currentAdjustment = CGFloat(0)
	/// You can't KVO UIKit properties, so we can't KVO center. But if adjustee.center has changed by some other reason
	/// (device rotation is the one I see often) we should discard the adjustment and redo the math. This stores
	/// the last observed center
	private var previousCenter = CGPointZero

	// MARK: BaseViewAboveKeyboard overrides
	override func update() {
		// If the keyboardRect is height zero (happens during when targetView is set, but the keyboard isn't
		// onscreen), go ahead and zero any extant adjustments and bail.
		if keyboardRect.height == 0 {
			zeroAdjustments()
			return
		}

		if let adjustee = adjustee,
			targetView = targetView,
			targetSuper = targetView.superview where targetView.isDescendantOfView(adjustee) {
				// If adjustee.center has changed elsewhere then zero out currentAdjustment
				if adjustee.center != previousCenter {
					debug.logAtLevel(.Debug, message: "Adjusting for center drift, losing \(self.currentAdjustment)")
					currentAdjustment = 0
				}

				// TargetView may not be a direct child of adjustee, just somewhere in the child hierarchy. So in order
				// to do the math we need to adjust targetView's origin into adjustee's local space.
				let targetFrame = targetSuper.convertRect(targetView.frame, toView:adjustee)
				let targetViewBottomY = targetFrame.origin.y + targetFrame.size.height
				debug.logAtLevel(.Debug, message: "Adjustee frame: \(adjustee.frame), center: \(adjustee.center)")
				debug.logAtLevel(.Debug, message: "TargetFrame: \(targetFrame), bottom: \(targetViewBottomY)")
				// Pretend the keyboardRect starts at the top of the padding for the purposes of this math. Note that
				// after the first adjustment verticalDelta starts containing the padding from previous passes (because
				// the padding moves keyboardRect as well.)
				let verticalDelta = keyboardRect.origin.y - padding - targetViewBottomY;
				let animBlock = { () -> Void in
					adjustee.center = CGPointMake(adjustee.center.x, adjustee.center.y + verticalDelta);
				}

				// If targetViewBottomY is inside keyboardRect then we need to move
				if verticalDelta < 0.0 {
					UIView.animateWithDuration(animDuration,
						delay: 0,
						options: animOptions,
						animations: animBlock) { [weak self] _ -> Void in self?.completionBlock?() }
					currentAdjustment += verticalDelta
				}
					// TargetViewBottomY is not inside keyboardRect. If we have previously adjusted we should spend
					// some/all of it.
				else if currentAdjustment < 0.0 {
					// If currentAdjusment is less than -verticalDelta we want to roll off verticalDelta worth
					if currentAdjustment < -verticalDelta {
						debug.logAtLevel(.Debug, message: "Rolling off \(verticalDelta) worth of adjustment.")
						UIView.animateWithDuration(animDuration,
							delay: 0,
							options: animOptions,
							animations: animBlock) { [weak self] _ -> Void in self?.completionBlock?() }
						currentAdjustment += verticalDelta
					}
						// currentAdjustment is less than -newAdjustment, we can zero it out now.
					else {
						zeroAdjustments()
					}
				}
				debug.logAtLevel(.Debug, message: "CurrentAdjustment:\(currentAdjustment)")
				previousCenter = adjustee.center
				adjustmentBlock?()
		}
	}

	/// Clear out currentAdjustment. If it still had a value left animate it away.
	override func zeroAdjustments() {
		debug.logAtLevel(.Debug,
			message: "Zeroing keyboard adjustment, current constant:\(currentAdjustment)")
		if let adjustee = adjustee {
			if currentAdjustment < 0 {
				UIView.animateWithDuration(animDuration,
					delay: 0,
					options: animOptions,
					animations: { () -> Void in
						// From a purist perspective I'd like to capture self weak ([weak self] here. But if I do that
						// I can't call this func from deinit. Since deinit should probably zero out the adjustment 
						// we need to make a strong capture. This is OK, the animation will definitely finish, and then
						// the strong pointer will go away.
						debug.logAtLevel(.Debug, message: "Zeroing rolling off \(self.currentAdjustment)")
						adjustee.center = CGPointMake(adjustee.center.x,
							adjustee.center.y - self.currentAdjustment);
					}) { _  -> Void in self.completionBlock?() }
				self.currentAdjustment = 0
				previousCenter = adjustee.center
				adjustmentBlock?()
			}
		}
	}
}

