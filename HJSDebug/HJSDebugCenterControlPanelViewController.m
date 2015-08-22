//  Created by Timothy Sanders on 5/9/14.
//
//

#import "HJSDebugCenterControlPanelViewController.h"

#import "HJSDebugCenter.h"

@implementation HJSDebugCenterControlPanelViewController
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];

#if BETA
	_adHocLabel.hidden = YES;
	_adHocSwitch.hidden = YES;
	_breakEnabledLabel.hidden = YES;
	_breakEnabledSwitch.hidden = YES;
	_resetCoreDataButton.hidden = YES;
#endif

	// The buttons at the bottom get cramped on an iPhone. Let them shrink font size instead of
	// clipping with an ellipsis.
	CGFloat minimumScale = 10.0 / _resetCoreDataButton.titleLabel.font.pointSize;
	_resetCoreDataButton.titleLabel.adjustsFontSizeToFitWidth = YES;
	_resetCoreDataButton.titleLabel.minimumScaleFactor = minimumScale;
	_mailLogButton.titleLabel.adjustsFontSizeToFitWidth = YES;
	_mailLogButton.titleLabel.minimumScaleFactor = minimumScale;
	_dismissButton.titleLabel.adjustsFontSizeToFitWidth = YES;
	_dismissButton.titleLabel.minimumScaleFactor = minimumScale;

	HJSDebugCenter * debug = [HJSDebugCenter existingCenter];
 	_adHocSwitch.on = debug.adHocDebugging;
	_breakEnabledSwitch.on = debug.debugBreakEnabled;
	switch (debug.logLevel) {
		case HJSLogLevelCritical:
			_loglevelSegmentedController.selectedSegmentIndex = 0;
			break;
			
		case HJSLogLevelWarning:
			_loglevelSegmentedController.selectedSegmentIndex = 1;
			break;
			
		case HJSLogLevelDebug:
			_loglevelSegmentedController.selectedSegmentIndex = 3;
			break;
			
		case HJSLogLevelInfo:
		default:
			_loglevelSegmentedController.selectedSegmentIndex = 2;
			break;
	}

	int index = 0;
	[_logSelector removeAllSegments];
	[_logSelector insertSegmentWithTitle:@"App" atIndex:index animated:NO];
	++index;

	for (NSString * key in debug.monitoredLogKeys) {
		[_logSelector insertSegmentWithTitle:key atIndex:index animated:NO];
		++index;
	}
	_logSelector.selectedSegmentIndex = 0;
	if (index == 1) { // If we only have one log in the control go ahead and hide it.
		_logSelector.hidden = YES;
	}
	[self changeLog:self];
}

- (IBAction)mailLog:(id)sender {
	// Acquire the bundle display name to use in the subject
	NSDictionary * mainBundleInfo = [[NSBundle mainBundle] infoDictionary];
	NSString * subject = @"Debug Log";
	NSString * displayName = [mainBundleInfo objectForKey:@"CFBundleDisplayName"];
	if (displayName) {
		subject = [NSString stringWithFormat:@"%@ Debug Log", displayName];
	}

	UIViewController * presenter = self.presentingViewController;
	[self dismissViewControllerAnimated:YES completion:^{
		[[HJSDebugCenter existingCenter]
		 presentMailLogWithExplanation:@"This log was requested via the debug control panel."
		 subject:subject
		 fromViewController:presenter];
	}];
}

- (IBAction)toggleAdHoc:(id)sender {
	HJSDebugCenter * debug = [HJSDebugCenter existingCenter];
	debug.adHocDebugging =  _adHocSwitch.on;
	[debug saveSettings];
}

- (IBAction)toggleBreakEnabled:(id)sender {
	HJSDebugCenter * debug = [HJSDebugCenter existingCenter];
	debug.debugBreakEnabled = _breakEnabledSwitch.on;
	[debug saveSettings];
}

- (IBAction)changeLog:(id)sender {
	HJSDebugCenter * debug = [HJSDebugCenter existingCenter];

	if (_logSelector.selectedSegmentIndex == 0) {
		_logText.text = debug.mainLogAsString;
	}
	else {
		NSString * key = [_logSelector titleForSegmentAtIndex:_logSelector.selectedSegmentIndex];
		_logText.text = [debug monitoredLogAsString:key];
	}

	[_logText scrollRangeToVisible:NSMakeRange([_logText.text length], 0)];
	[_logText setScrollEnabled:NO];
	[_logText setScrollEnabled:YES];
}

- (IBAction)changeLogLevel:(id)sender {
	HJSDebugCenter * debug = [HJSDebugCenter existingCenter];

	switch (_loglevelSegmentedController.selectedSegmentIndex) {
		case 0:
			debug.logLevel = HJSLogLevelCritical;
			break;
			
		case 1:
			debug.logLevel = HJSLogLevelWarning;
			break;

		case 3:
			debug.logLevel = HJSLogLevelDebug;
			break;
			
		case 2:
		default:
			debug.logLevel = HJSLogLevelInfo;
			break;
	}

	[debug saveSettings];
}
- (IBAction)resetCoreData:(id)sender {
//	HJSCoreDataCenter * coreData = [HJSCoreDataCenter defaultCenter];
//	[coreData resetStack];
}

- (IBAction)dismissSelf:(id)sender {
	[self dismissViewControllerAnimated:YES completion:NULL];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    return self;
}
@end
