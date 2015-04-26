//
//  HJSHelpViewDelegate.swift
//  HJSHelpView
//
//  Created by Timothy Sanders on 2015-04-25.
//  Copyright (c) 2015 HIddenJester Software. All rights reserved.
//

import UIKit

import HJSDebug

private let debug = HJSDebugCenter.existingCenter()

enum HelpViewTransition {
	case None
	case InitialLoad
	case Forward
	case Insert
	case Back
	case NewEntry
}

public class HJSHelpViewDelegate :  NSObject, UIWebViewDelegate {
	@IBOutlet weak private(set) var toolbar: UIToolbar!
	@IBOutlet weak private(set) var backButton: UIBarButtonItem!
	@IBOutlet weak private(set) var forwardButton: UIBarButtonItem!
	@IBOutlet weak private(set) var creditsButton: UIBarButtonItem!
	@IBOutlet weak private(set) var rateButton: UIBarButtonItem!
	@IBOutlet weak private(set) var webView: UIWebView!

	private var pages = Array<String>()
	private var currentPage = 0
	private var currentTransition = HelpViewTransition.None

	private var processingPageLoad = false

	var pageName: String = "" {
		willSet {
			if pageName != newValue && currentTransition == .None {
				currentTransition = .InitialLoad
			}
		}
		didSet {
			if pageName != oldValue && !processingPageLoad {
				loadPage()
			}
		}
	}

	@IBAction func backTapped(sender: AnyObject) {
		currentTransition = .Back
		loadPage()
	}

	@IBAction func forwardTapped(sender: AnyObject) {
		currentTransition = .Forward
		loadPage()
	}

	@IBAction func openCredits(sender: AnyObject) {
		currentTransition = .Insert
		pageName = "Credits"
	}

	@IBAction func rateApp(sender: AnyObject) {
		// TIMTODO: Genericize the URL
		if let URL = NSURL(string: "itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=915191563") {
			debug.logAtLevel(.Debug, message: "Opening iTunes URL for app rating.")
			UIApplication.sharedApplication().openURL(URL)
		}
		else {
			debug.logAtLevel(.Critical, message: "Couldn't create the rate app URL!")
		}
	}

	private func loadPage() {
		var newPage: String? = nil

		switch currentTransition {
		case .None:
			// This should never happen.
			debug.logAtLevel(.Critical, message: "Transition is not set correctly.")

		case .InitialLoad:
			if pages.count > 0 {
				debug.logAtLevel(.Critical, message: "Initial load called with pages in stack")
			}
			currentPage = 0
			pages = [pageName]
			newPage = pageName

		case .Forward:
			if currentPage >= pages.count - 1 {
				debug.logAtLevel(.Critical, message: "Forward called when at end of array.")
			}
			else {
				++currentPage
				newPage = pages[currentPage]
			}
		case .Insert:
			// This is similar to NewEntry but we haven't loaded the file yet. (Used by the credits button which 
			// inserts into the stack.)
			if currentPage < pages.count - 1 {
				// Throw away everything past this node in the stack
				pages = Array(pages[0...currentPage])
			}
			pages.append(pageName)
			newPage = pageName
			currentPage = pages.count - 1

		case .NewEntry:
			// We can now update the stack since request.URL is now current
			if currentPage < pages.count - 1 {
				// Throw away everything past this node in the stack
				pages = Array(pages[0...currentPage])
			}
			pages.append(pageName)
			currentPage = pages.count - 1

		case .Back:
			if currentPage == 0 {
				debug.logAtLevel(.Critical, message: "Back hit while at page 0 in help.")
			}
			else {
				--currentPage
				newPage = pages[currentPage]
			}
		}

		if let newPage = newPage {
			debug.logAtLevel(.Debug, message: "Loading help page \(newPage)")
			var error: NSError? = nil
			let bundle = NSBundle.mainBundle()
			if let resourceURL = bundle.URLForResource(newPage, withExtension: "html", subdirectory: "HTML"),
				htmlString = String(contentsOfURL: resourceURL, encoding: NSUTF8StringEncoding, error: &error) {
					webView.loadHTMLString(htmlString, baseURL: resourceURL)
			}
			else {
				debug.logError(error)
			}
		}
	}

	// MARK: UIWebViewDelegate methods
	public func webView(webView: UIWebView,
		shouldStartLoadWithRequest request: NSURLRequest,
		navigationType: UIWebViewNavigationType) -> Bool {
			if let requestURL = request.URL {
				debug.logAtLevel(.Debug, message: "HelpView received NSURLRequest \(requestURL.absoluteString)")
				// We only load local HTML pages in HJSHelpView. Return true so we handle this.
				if requestURL.fileURL {
					return true
				}

				// Pass this off to some other app
				UIApplication.sharedApplication().openURL(requestURL)
				return false;
			}

			// If we got here then the let requestURL assignment failed.
			debug.logAtLevel(.Critical, message: "Request doesn't have a URL?")
			return false
	}

	public func webViewDidStartLoad(webView: UIWebView) {
		if currentTransition == .None {
			// This is a link tap
			currentTransition = .NewEntry
		}

		// Disable the nav buttons while we load new content
		// Note: this should be animated, but UIButton doesn't (as of iOS 7.1) support animating enabled
		backButton.enabled = false
		forwardButton.enabled = false
	}

	public func webViewDidFinishLoad(webView: UIWebView) {
		if let newPageName = webView.request?.URL?.lastPathComponent?.stringByDeletingPathExtension {
			processingPageLoad = true
			pageName = newPageName
			processingPageLoad = false
			if currentTransition == .NewEntry {
				loadPage()
			}
		}

		creditsButton.enabled = (pageName != "Credits")
		backButton.enabled = currentPage > 0
		forwardButton.enabled = currentPage + 1 < pages.count
		currentTransition = .None
	}

	deinit {
		debug.logMessage("HelpViewDelegate deinit")
		webView.delegate = nil
	}
}
