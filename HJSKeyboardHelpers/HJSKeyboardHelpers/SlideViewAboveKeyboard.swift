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
Slides a view upward as the keyboard needs, and then you can specify which child view needs to be right above the
top of the keyboard. This class provides all of the functions of BaseViewAboveKeyboard.

:warning: This class is designed for a simple UIView that just needs to be slid upward and has no constraints attached
	to the view's bottom layout guide. If you have constraints like that you probably want ShrinkViewAboveKeyboard.

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
				// TargetView may not be a direct child of adjustee, just somewhere in the child hierarchy. So in order
				// to do the math we need to adjust targetView's origin into adjustee's local space.
				let targetFrame = targetSuper.convertRect(targetView.frame, toView:adjustee)
				let targetViewBottomY = targetFrame.origin.y + targetFrame.size.height
				// Pretend the keyboardRect starts at the top of the padding for the purposes of this math. Note that
				// after the first adjustment verticalDelta starts containing the padding from previous passes (because
				// the padding moves keyboardRect as well.)
				let verticalDelta = keyboardRect.origin.y - padding - targetViewBottomY;
				// If targetViewBottomY is inside keyboardRect then we need to move
				if verticalDelta < 0.0 {
					UIView.animateWithDuration(animDuration,
						delay: 0,
						options: animOptions,
						animations: { () -> Void in
							adjustee.center = CGPointMake(adjustee.center.x, adjustee.center.y + verticalDelta);
						},
						completion: nil)
					currentAdjustment += verticalDelta
				}
					// TargetViewBottomY is not inside keyboardRect. If we have previously adjusted we should spend
					// some/all of it.
				else if currentAdjustment < 0.0 {
					// If the currentAdjustment is less than -verticalDelta we want to roll off vertDelta's worth
					if currentAdjustment < -verticalDelta {
						UIView.animateWithDuration(animDuration,
							delay: 0,
							options: animOptions,
							animations: { () -> Void in
								adjustee.center = CGPointMake(adjustee.center.x, adjustee.center.y + verticalDelta);
							},
							completion: nil)
						currentAdjustment += verticalDelta
					}
						// currentAdjustement is less than -verticalDelta, we can zero it out now.
					else {
						zeroAdjustments()
					}
				}
				adjustmentBlock?()
		}
	}

	/// Clear out currentAdjustment. If it still had a value left animate it away.
	override func zeroAdjustments() {
		if let adjustee = adjustee where currentAdjustment < 0.0 {
			UIView.animateWithDuration(animDuration,
				delay: 0,
				options: animOptions,
				animations: { () -> Void in
					// From a purist perspective I'd like to capture self weak ([weak self] here. But if I do that I 
					// can't call this func from deinit. Since deinit should probably zero out the adjustment we need
					// to make a strong capture. This is OK, the animation will definitely finish, and then the strong
					// pointer will go away.
					adjustee.center = CGPointMake(adjustee.center.x,
						adjustee.center.y - (self.currentAdjustment ?? 0));
				},
				completion: nil)
			currentAdjustment = 0
			adjustmentBlock?()
		}
	}
}

