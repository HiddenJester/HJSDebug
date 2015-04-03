//
//  ShrinkViewAboveKeyboard.swift
//  HJSExtension
//
//  Created by Timothy Sanders on 2014-12-07.
//  Copyright (c) 2014 HIddenJester Software. All rights reserved.
//  Created by Timothy Sanders on 2014-12-04.
//  Copyright (c) 2014 HIddenJester Software. All rights reserved.
// This work is licensed under the Creative Commons Attribution-ShareAlike 4.0
// International License. To view a copy of this license, visit
// http://creativecommons.org/licenses/by-sa/4.0/deed.en_US.//

import UIKit

/**
:brief:
Shrinks a view as needed to it above the keyboard. This class provides all of the functions of BaseViewAboveKeyboard.

:warning:
This class will adjust the view's height. If you have extensive vertical constraints this will likely cause autolayout
to freak on a landscape phone.

:warning:
If you shrink a view and set padding then the superview will show through. The default mainWindow has a black
backgroundColor which probably doens't match your view. Either put a view *inside* your main view and shrink that or 
in the viewWillAppear you can set view.superview?.backgroundColor to what you want to show through.

Objective C usage (called from a UIViewController):

:code:
ShrinkViewAboveKeyboard * _keyboardWatcher = [[ShrinkViewAboveKeyboard alloc] initWithView:self.view];
_keyboardWatcher.targetView = _detailField;

*/
@objc public class ShrinkViewAboveKeyboard : BaseViewAboveKeyboard {
	/// As we move adjustees height view we track the amount we've moved it here
	private var currentAdjustment = CGFloat(0)

	// MARK: BaseViewAboveKeyboard overrides
	override func update() {
		// Bail if we're not configured to do anything useful.
		if hasInvalidState() {
			return
		}
		// At this point it's safe to force-unwrap adjustee

		// We operate in adjustee local space so we don't care if adjustee's origin is non-zero
		let verticalDelta = keyboardRect.origin.y - adjustee!.frame.size.height;
		// If currentAdjustment is zero then this is our first adjustment and we want to add the padding into
		// verticalDelta
		let paddingDelta = (currentAdjustment == 0) ? padding : 0

		// If adjustee is inside keyboardRect then we need to move
		if verticalDelta - paddingDelta < 0.0 {
			UIView.animateWithDuration(animDuration,
				delay: 0,
				options: animOptions,
				animations: { () -> Void in
					self.adjustee!.frame.size = CGSizeMake(self.adjustee!.frame.size.width,
						self.adjustee!.frame.size.height + verticalDelta - paddingDelta)
				}) { _ in
					self.callCompletionBlock()
				}

			currentAdjustment += verticalDelta
		}
		// Adjustee is not inside keyboardRect. If we have previously adjusted we should spend some/all of it.
		else if currentAdjustment < 0.0 {
			// If the currentAdjustment is less than -verticalDelta we want to roll off vertDelta's worth
			if currentAdjustment < -verticalDelta {
				UIView.animateWithDuration(animDuration,
					delay: 0,
					options: animOptions,
					animations: { () -> Void in
						self.adjustee!.frame.size = CGSizeMake(self.adjustee!.frame.size.width,
							self.adjustee!.frame.size.height + verticalDelta)
					}) { _ in
						self.callCompletionBlock()
				}

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
						// Roll off the padding as well
						self.adjustee!.frame.size = CGSizeMake(self.adjustee!.frame.size.width,
							self.adjustee!.frame.size.height - self.currentAdjustment + self.padding)
					}) { _ in
						self.callCompletionBlock()
				}
				currentAdjustment = 0
			}
		}
	}

	// Nothing special to check in an override of hasInvalidState, so skip it.
}
