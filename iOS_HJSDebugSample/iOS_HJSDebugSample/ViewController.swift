//
//  ViewController.swift
//  iOS_HJSDebugSample
//
//  Created by Timothy Sanders on 2015-10-04.
//  Copyright © 2015 HiddenJester Software. All rights reserved.
//

import UIKit
import HJSDebug

class ViewController: UIViewController {
	@IBOutlet weak var levelControl: UISegmentedControl!

	@IBAction func logFieldEditingDidEnd(_ sender: AnyObject) {
		guard let textField = sender as? UITextField else {
			return
		}

		guard let message = textField.text, textField.text?.characters.count > 0 else {
			return
		}

		debug.log(at: mapSegmentToLogLevel(), message: message)
		textField.text = nil
		textField.resignFirstResponder()
	}

	@IBAction func onShowControlPanel(_ sender: AnyObject) {
		debug.presentControlPanel(from: self)
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		// Yeah, yeah a magic number. This is just a sample app, not really worth establishing a full mapping from
		// the segmented controls index to HJSLogLevel. Anyway, let's start at Debug.
		levelControl.selectedSegmentIndex = 3
	}

	fileprivate func mapSegmentToLogLevel() -> HJSLogLevel {
		let logLevels: [HJSLogLevel] = [.critical, .warning, .info, .debug]
		if levelControl.selectedSegmentIndex < logLevels.count {
			return logLevels[levelControl.selectedSegmentIndex]
		}

		return .critical
	}
}

// 2016-09-11 The Swift 3 convertor wrote these. They are both required to implement the guard in 
// logFieldEditingDidEnd where we check textField.text?.characters.count > 0
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l > r
    default:
        return rhs < lhs
    }
}
