//
//  HJSHelpView.swift
//  HJSHelpView
//
//  Created by Timothy Sanders on 2015-04-24.
//  Copyright (c) 2015 HIddenJester Software. All rights reserved.
//

import UIKit

import HJSDebug

private let debug = HJSDebugCenter.existingCenter()

//@IBDesignable
@objc public class HJSHelpView : UIView {
	// This isn't a weak pointer, we really own the delegate we fished out of the nib.
	@IBOutlet public private(set) var delegate: HJSHelpViewDelegate!

	required public init(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)

		addXib()
	}

	override init(frame: CGRect) {
		super.init(frame: frame)

		addXib()
	}

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