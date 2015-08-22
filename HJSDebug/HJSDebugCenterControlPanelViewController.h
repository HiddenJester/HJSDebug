//  Created by Timothy Sanders on 5/9/14.
//
//

@import UIKit;

@interface HJSDebugCenterControlPanelViewController : UIViewController

@property (weak, nonatomic) IBOutlet UILabel * adHocLabel;
@property (nonatomic, weak) IBOutlet UISwitch * adHocSwitch;
@property (weak, nonatomic) IBOutlet UILabel * breakEnabledLabel;
@property (weak, nonatomic) IBOutlet UISwitch * breakEnabledSwitch;
@property (nonatomic, weak) IBOutlet UISegmentedControl * loglevelSegmentedController;
@property (nonatomic, weak) IBOutlet UITextView * logText;
@property (weak, nonatomic) IBOutlet UISegmentedControl *logSelector;
@property (weak, nonatomic) IBOutlet UIButton *mailLogButton;
@property (weak, nonatomic) IBOutlet UIButton *resetCoreDataButton;
@property (weak, nonatomic) IBOutlet UIButton *dismissButton;

@end
