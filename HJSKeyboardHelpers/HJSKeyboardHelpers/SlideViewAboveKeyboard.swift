//
//  SlideViewAboveKeyboard.swift
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

Slides a view upward as the keyboard needs, and then you can specify which child view needs to be right above the
top of the keyboard. This class provides all of the functions of BaseViewAboveKeyboard.

:warning:
This class is designed for a simple UIView that just needs to be slid upward and has no constraints attached to the
view's bottom layout guide. In that case you probably want ShrinkViewAboveKeyboard.

Objective C usage (called from a UIViewController):

:code:
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

	/// As we move adjustees center view we track the amount we've moved it here
	private var currentAdjustment = CGFloat(0)

	// MARK: BaseViewAboveKeyboard overrides
	override func update() {
		// Bail if we're not configured to do anything useful.
		if hasInvalidState() {
			return
		}
		// At this point it's safe to force-unwrap targetView, adjustee, and targetView.superview (because
		// we know at the very least that adjustee is a superView of targetView). If none of those worked
		// hasInvalidState would have returned true.

		// TargetView may not be a direct child of adjustee, just somewhere in the child hierarchy. So in order to
		// do the math we need to adjust targetView's origin into scrolleeView's local space.
		let targetFrame = targetView!.superview!.convertRect(targetView!.frame, toView:adjustee!)
		let targetViewBottomY = targetFrame.origin.y + targetFrame.size.height
		// Pretend the keyboardRect starts at the top of the padding for the purposes of this math. Note that 
		// after the first adjustment verticalDelta starts containing the padding from previous passes (because the
		// padding moves keyboardRect as well.)
		let verticalDelta = keyboardRect.origin.y - padding - targetViewBottomY;
		// If currentAdjustment is zero then this is our first adjustment and we want to add the padding into
		// verticalDelta

		// If targetViewBottomY is inside keyboardRect then we need to move
		if verticalDelta < 0.0 {
			UIView.animateWithDuration(animDuration,
				delay: 0,
				options: animOptions,
				animations: { () -> Void in
					self.adjustee!.center = CGPointMake(self.adjustee!.center.x,
						self.adjustee!.center.y + verticalDelta);
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
						self.adjustee!.center = CGPointMake(self.adjustee!.center.x,
							self.adjustee!.center.y + verticalDelta);
					},
					completion: nil)
				currentAdjustment += verticalDelta
			}
			// currentAdjustement is less than -verticalDelta, we can zero it out now.
			else {
				zeroAdjustments()
			}
		}

		callAdjustmentBlock()
	}

	/// Clear out currentAdjustment. If it still had a value left animate it away.
	override func zeroAdjustments() {
		if currentAdjustment < 0.0 {
			if let view = adjustee {
				UIView.animateWithDuration(animDuration,
					delay: 0,
					options: animOptions,
					animations: { () -> Void in
						view.center = CGPointMake(view.center.x,
							view.center.y - self.currentAdjustment);
					},
					completion: nil)
				currentAdjustment = 0
			}
		}
	}

	/**
	Test that we have both weak view references and that targetView is a child of adjustee. If any of those
	are false then we probably just want to skip whatever it was we were about to try.
	
	:returns: true if something is wrong, false if we can proceed with the math
	*/
	override func hasInvalidState() -> Bool {
		// Ask super, which will check for adjustee's existence
		if super.hasInvalidState() {
			return true
		}
		// No point if we don't have targetView or if targetView isn't a child of adjustee.
		// Note the second test can safely unwrap targetView because if it was
		// nil then the first test would have triggered and we'd short-circuit
		if  targetView == nil || !targetView!.isDescendantOfView(adjustee!) {
			debug.logMessage("SlideViewAboveKeyboard is installed but has no work to do.")
			return true
		}
		return false
	}
}

