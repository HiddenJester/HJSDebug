//
//  HJSHelpView.swift
//  HJSHelpView
//
//  Created by Timothy Sanders on 2015-04-24.
//  Copyright (c) 2015 HiddenJester Software.
//	This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
//	See http://creativecommons.org/licenses/by-nc-sa/4.0/

import UIKit

import HJSDebug

private let debug = HJSDebugCenter.existingCenter()

/**
HJSHelpView loads html files from a folder named HTML in the app bundle and displays them in a UIWebView. A toolbar
provides forward/back navigation in a stack, links are properly loaded (non-file URLs are shelled out to Mail or
Safari or whatever should handle them.) The toolbar also has a button to open a Credits page, a button to open
the Reviews tab in the App Store, and the ability to insert buttons at runtime. See HJSHelpViewDelegate for most of
these functions, and access the delegate via the delegate property.
*/
@objc public class HJSHelpView : UIView {
	// This isn't a weak pointer, we really own the delegate we fished out of the nib.
	/// The HJSHelpViewDelegate that manages this help view. This is loaded from the nib when needed.
	@IBOutlet public private(set) var delegate: HJSHelpViewDelegate!

	required public init(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)

		addXib()
	}

	override init(frame: CGRect) {
		super.init(frame: frame)

		addXib()
	}

	/// Code to load the nib from the framework, create the needed constraints, and add the view as a subview.
	private func addXib() {
		let bundle = NSBundle(forClass: self.dynamicType)
		let nibName = "HJSHelpView"
		// loadNibNamed throws an exception so make sure the nib file (with URLForResource) is here before proceeding
		if let nibURL = bundle.URLForResource(nibName, withExtension: "nib"),
			objects = bundle.loadNibNamed(nibName, owner: self, options: nil),
			newView = objects[0] as? UIView {
				newView.setTranslatesAutoresizingMaskIntoConstraints(false)
				addSubview(newView)
				let constraints = [
					NSLayoutConstraint(item: self, attribute: .Leading, relatedBy: .Equal,
						toItem: newView, attribute: .Leading,
						multiplier: 1.0, constant: 0),
					NSLayoutConstraint(item: self, attribute: .Trailing, relatedBy: .Equal,
						toItem: newView, attribute: .Trailing,
						multiplier: 1.0, constant: 0),
					NSLayoutConstraint(item: self, attribute: .Top, relatedBy: .Equal,
						toItem: newView, attribute: .Top,
						multiplier: 1.0, constant: 0),
					NSLayoutConstraint(item: self, attribute: .Bottom, relatedBy: .Equal,
						toItem: newView, attribute: .Bottom,
						multiplier: 1.0, constant: 0)
				]
				addConstraints(constraints)
		}
		else {
			debug.logAtLevel(.Critical, message: "Help View XIB didn't load!")
		}
	}
}