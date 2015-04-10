//
//  ShrinkViewAboveKeyboard.swift
//  HJSExtension
//
//  Created by Timothy Sanders on 2014-12-07.
//  Copyright (c) 2014 HIddenJester Software. All rights reserved.
// This work is licensed under the Creative Commons Attribution-ShareAlike 4.0
// International License. To view a copy of this license, visit
// http://creativecommons.org/licenses/by-sa/4.0/deed.en_US.//

import UIKit

/** 
Shrinks a view as needed to keep it above the keyboard. This class provides all of the functions of
BaseViewAboveKeyboard.

:Warning: This class will adjust the view's height. If you have extensive vertical constraints this will likely cause
	autolayout to freak on a landscape phone. This also requires a view that isn't being sized from constraints. (Using
	a top level view is the general use case.)

:Warning: If you shrink a view and set padding then the superview will show through. The default mainWindow has
	a black backgroundColor which probably doens't match your view. Either put a view *inside* your main view and 
	shrink that or in the viewWillAppear you can set view.superview?.backgroundColor to what you want to show through.

Objective C usage (called from a UIViewController):

	ShrinkViewAboveKeyboard * _keyboardWatcher = [[ShrinkViewAboveKeyboard alloc] initWithView:self.view];
	_keyboardWatcher.targetView = _detailField;

*/
@objc public class ShrinkViewAboveKeyboard : BaseViewAboveKeyboard {
	/// As we move adjustees height view we track the amount we've moved it here
	private var currentAdjustment = CGFloat(0)

	// MARK: BaseViewAboveKeyboard overrides
	override func update() {
		if let adjustee = adjustee {
			// We operate in adjustee local space so we don't care if adjustee's origin is non-zero
			let verticalDelta = keyboardRect.origin.y - adjustee.frame.size.height;
			// If currentAdjustment is zero then this is our first adjustment and we want to add the padding into
			// verticalDelta
			let paddingDelta = (currentAdjustment == 0) ? padding : 0

			// If adjustee is inside keyboardRect then we need to move
			if verticalDelta - paddingDelta < 0.0 {
				UIView.animateWithDuration(animDuration,
					delay: 0,
					options: animOptions,
					animations: { () -> Void in
						adjustee.frame.size = CGSizeMake(adjustee.frame.size.width,
							adjustee.frame.size.height + verticalDelta - paddingDelta)
					}) { [weak self] _ in self?.completionBlock?() }
				currentAdjustment += verticalDelta
			}
				// Else Adjustee is not inside keyboardRect. If we have previously adjusted we should spend some/all
				// of it.
			else if currentAdjustment < 0.0 {
				// If the currentAdjustment is less than -verticalDelta we want to roll off vertDelta's worth
				if currentAdjustment < -verticalDelta {
					UIView.animateWithDuration(animDuration,
						delay: 0,
						options: animOptions,
						animations: { () -> Void in
							adjustee.frame.size = CGSizeMake(adjustee.frame.size.width,
								adjustee.frame.size.height + verticalDelta)
						}) { [weak self] _ in self?.completionBlock?() }
					currentAdjustment += verticalDelta
				}
					// Else currentAdjustement is less than -verticalDelta, we can zero it out now.
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
				animations: { [weak self] () -> Void in
					if let blockSelf = self {
						// Roll off the padding as well
						adjustee.frame.size = CGSizeMake(adjustee.frame.size.width,
							adjustee.frame.size.height - blockSelf.currentAdjustment + blockSelf.padding)
					}
				}) { [weak self] _ in self?.completionBlock?() }
			adjustmentBlock?()
			currentAdjustment = 0
		}
	}
}
