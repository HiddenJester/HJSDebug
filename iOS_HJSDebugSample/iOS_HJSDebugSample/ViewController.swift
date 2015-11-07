//
//  ViewController.swift
//  iOS_HJSDebugSample
//
//  Created by Timothy Sanders on 2015-10-04.
//  Copyright © 2015 HiddenJester Software. All rights reserved.
//

import UIKit
import HJSDebugiOS

class ViewController: UIViewController {
	@IBOutlet weak var levelControl: UISegmentedControl!

	@IBAction func logFieldEditingDidEnd(sender: AnyObject) {
		guard let textField = sender as? UITextField else {
			return
		}

		guard let message = textField.text where textField.text?.characters.count > 0 else {
			return
		}

		debug.logAtLevel(mapSegmentToLogLevel(), message: message)
		textField.text = nil
		textField.resignFirstResponder()
	}

	@IBAction func onShowControlPanel(sender: AnyObject) {
		debug.presentControlPanelFromViewController(self)
	}

	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		// Yeah, yeah a magic number. This is just a sample app, not really worth establishing a full mapping from
		// the segmented controls index to HJSLogLevel. Anyway, let's start at Debug.
		levelControl.selectedSegmentIndex = 3
	}

	private func mapSegmentToLogLevel() -> HJSLogLevel {
		let logLevels: [HJSLogLevel] = [.Critical, .Warning, .Info, .Debug]
		if levelControl.selectedSegmentIndex < logLevels.count {
			return logLevels[levelControl.selectedSegmentIndex]
		}

		return .Critical
	}
}

