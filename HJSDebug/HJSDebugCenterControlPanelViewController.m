//  Created by Timothy Sanders on 5/9/14.
//
//

#import "HJSDebugCenterControlPanelViewController.h"

#import "HJSDebugCenter.h"

@implementation HJSDebugCenterControlPanelViewController

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	_logText.text = [[HJSDebugCenter defaultCenter] logContents];
	_adHocSwitch.on = [HJSDebugCenter defaultCenter].adHocDebugging;
	switch ([HJSDebugCenter defaultCenter].logLevel) {
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
}

- (IBAction)mailLog:(id)sender {
	[self dismissViewControllerAnimated:YES completion:^{
		[[HJSDebugCenter defaultCenter] mailLogWithExplanation:@"This log was requested via the debug control panel."];
	}];
}

- (IBAction)toggleAdHoc:(id)sender {
	[[HJSDebugCenter defaultCenter] setAdHocDebugging:_adHocSwitch.on];
	[[HJSDebugCenter defaultCenter] saveSettings];
}

- (IBAction)changeLogLevel:(id)sender {
	HJSLogLevel level;
	switch (_loglevelSegmentedController.selectedSegmentIndex) {
		case 0:
			level = HJSLogLevelCritical;
			break;
			
		case 1:
			level = HJSLogLevelWarning;
			break;

		case 3:
			level = HJSLogLevelDebug;
			break;
			
		case 2:
		default:
			level = HJSLogLevelInfo;
			break;
	}
	[[HJSDebugCenter defaultCenter] setLogLevel:level];
	[[HJSDebugCenter defaultCenter] saveSettings];
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
