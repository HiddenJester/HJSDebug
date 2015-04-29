//
//  HJSHelpViewDelegate.swift
//  HJSHelpView
//
//  Created by Timothy Sanders on 2015-04-25.
//  Copyright (c) 2015 HiddenJester Software.
//	This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
//	See http://creativecommons.org/licenses/by-nc-sa/4.0/

import UIKit

import HJSDebug

private let debug = HJSDebugCenter.existingCenter()

/// The possible transitions from what is being displayed to what we are about to display.
enum HelpViewTransition {
	case None				// No transition underway. An error if a load is occurring.
	case InitialLoad		// The help is opening, this is the first page to load.
	case NewEntry			// This transition was initiated by a link click in the current page.
	case Forward			// The user clicked the forward button, move forward in the page history stack.
	case Back				// The user clicked the back button, move backward in the page history stack.
	case Insert				// Similar to NewEntry, but triggered by code. (The credits button uses Insert.)
}

/**
HJSHelpView loads html files from a folder named HTML in the app bundle and displays them in a UIWebView. The delegate
manages the stack of pages and the IBAction for the toolbar. Set pageName to "foo" to display "foo.html" in the 
HJSHelpView.
*/
@objc public class HJSHelpViewDelegate :  NSObject, UIWebViewDelegate {
	// MARK: IBOutlets, set from the nib
	@IBOutlet weak private(set) var toolbar: UIToolbar!
	@IBOutlet weak private(set) var backButton: UIBarButtonItem!
	@IBOutlet weak private(set) var rateButton: UIBarButtonItem!
	/// There are two flexible spaces between rate & credits. buttonSpacer is the second one. addButton
	/// uses buttonSpacer so new buttons are added in the middle of the toolbar.
	@IBOutlet weak var buttonSpacer: UIBarButtonItem!
	@IBOutlet weak private(set) var creditsButton: UIBarButtonItem!
	@IBOutlet weak private(set) var forwardButton: UIBarButtonItem!

	@IBOutlet weak private(set) var webView: UIWebView!

	// MARK: Public vars
	/// pageName.html will be loaded from the HTML directory in the main bundle.
	public var pageName = "" {
		willSet {
			// If there isn't a current transition then treat this as an initial load.
			if pageName != newValue && currentTransition == .None {
				currentTransition = .InitialLoad
			}
		}
		didSet {
			// if the currentTransition is newEntry or this name set didn't come from webViewDidFinishLoad then
			// we need to call transitionPage.
			if pageName != oldValue && (!inDidFinshLoad || currentTransition == .NewEntry) {
				transitionPage()
			}
		}
	}

	/// The title displayed on the Rate App button.
	public var rateButtonTitle: String? {
		get { return rateButton.title }
		set { rateButton.title = newValue }
	}

	/// Set this to app ID as a string to properly set the URL used by the rate button.
	public var appIDString = "" { didSet { updateRateURL() } }

	// MARK: Private vars
	/// An array of pageNames looked at previously. The forward/back buttons navigate through this stack
	private var pages = Array<String>()
	/// Index into pages for the currently displayed page
	private var currentPage = 0
	private var currentTransition = HelpViewTransition.None
	/// Set in webViewDidFinishLoad before setting pageName so the observer knows when to not call transitionPage.
	private var inDidFinshLoad = false

	/// The URL used by the rateApp button. The default value opens the HiddenJester Software page in the app store.
	private var rateURL = NSURL(string: "itms://itunes.apple.com/us/artist/hiddenjester-software/id513157752")

	// MARK: Public functions
	/// There are two flexible spaces between the rate app button and the Credits button. This function adds newButton
	/// between the two spaces. If called multiple times buttons are added to the right of previous adds.
	public func addButton(newButton: UIBarButtonItem) {
		if var items = toolbar.items as? [UIBarButtonItem], index = find(items, buttonSpacer) {
			items.insert(newButton, atIndex: index)
			toolbar.items = items
		}
		else {
			debug.logAtLevel(.Critical, message: "Toolbar is misconfigured in addButton.")
		}
	}

	// MARK: IBActions
	@IBAction func backTapped(sender: AnyObject) {
		currentTransition = .Back
		transitionPage()
	}

	@IBAction func forwardTapped(sender: AnyObject) {
		currentTransition = .Forward
		transitionPage()
	}

	@IBAction func openCredits(sender: AnyObject) {
		currentTransition = .Insert
		pageName = "Credits"
	}

	@IBAction func rateApp(sender: AnyObject) {
		if let URL = rateURL {
			debug.logAtLevel(.Debug, message: "Opening iTunes URL \(URL.absoluteString)")
			UIApplication.sharedApplication().openURL(URL)
		}
		else {
			debug.logAtLevel(.Critical, message: "Rate App URL not configured!")
		}
	}

	// MARK: Internals
	// Process the specified transition, starts the webView loaded if needed.
	private func transitionPage() {
		var newPage: String? = nil	// If we need to load a new page newPage will be set.

		// NewEntry and Insert do much the same work. Capturing self strongly would be OK here, but this way is
		// safer for rewrites in the future in case the scope of this block changes.
		let newEntryOrInsertWork =  { [weak self]() -> Void in
			if let blockSelf = self {
				if blockSelf.currentPage < blockSelf.pages.count - 1 {
					// Throw away everything past this node in the stack
					blockSelf.pages = Array(blockSelf.pages[0...blockSelf.currentPage])
				}
				blockSelf.pages.append(blockSelf.pageName)
				blockSelf.currentPage = blockSelf.pages.count - 1
			}
		}

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

		case .NewEntry:
			// This transition was triggered by the webView so we've already started the load, don't need to update
			// newPage.
			newEntryOrInsertWork()

		case .Forward:
			if currentPage >= pages.count - 1 {
				debug.logAtLevel(.Critical, message: "Forward called when at end of array.")
			}
			else {
				++currentPage
				newPage = pages[currentPage]
			}

		case .Back:
			if currentPage == 0 {
				debug.logAtLevel(.Critical, message: "Back hit while at page 0 in help.")
			}
			else {
				--currentPage
				newPage = pages[currentPage]
			}

		case .Insert:
			// This is similar to NewEntry but we haven't loaded the file yet. (Used by the credits button which 
			// inserts into the stack.)
			newEntryOrInsertWork()
			// Since we haven't loaded the page yet, set newPage (unlike the NewEntry case).
			newPage = pageName
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
				// We only load local HTML pages in HJSHelpView. If this request is for a file URL return true.
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
			inDidFinshLoad = true
			pageName = newPageName
			inDidFinshLoad = false
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


	/**
	Turns appIDString into a URL that will open the Reviews tab for appID and updates rateURL.

	See https://stackoverflow.com/a/2337601/4834941 for a writeup on how to create these URL's that is current as of
	iOS 8. The crux of that is a reference to Apple's QA 1629:
	https://developer.apple.com/library/ios/qa/qa1629 (Note that you should replace http:// with itms://
	in those links to avoid the redirect through Safari.)
 
	This URL is created using the technique listed here:
	http://stackoverflow.com/a/23037620/4834941 with the itms:// for http:// replacement.
	
	:NOTE:
	2015-04-26 I tried all of the appstore.com links as specified in TN1633:
	https://developer.apple.com/library/ios/qa/qa1633 but I can't make them work on hardware at all, even just typing
	them into Safari doesn't work properly.
	*/
	private func updateRateURL() {
		let URLstring = "itms://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=\(appIDString)&pageNumber=0&sortOrdering=2&type=Purple+Software&mt=8"
		rateURL = NSURL(string: URLstring)
	}
}
