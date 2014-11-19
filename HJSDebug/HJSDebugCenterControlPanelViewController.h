//  Created by Timothy Sanders on 5/9/14.
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface HJSDebugCenterControlPanelViewController : UIViewController

@property (weak, nonatomic) IBOutlet UILabel * adHocLabel;
@property (nonatomic, weak) IBOutlet UISwitch * adHocSwitch;
@property (weak, nonatomic) IBOutlet UILabel * breakEnabledLabel;
@property (weak, nonatomic) IBOutlet UISwitch * breakEnabledSwitch;
@property (nonatomic, weak) IBOutlet UISegmentedControl * loglevelSegmentedController;
@property (nonatomic, weak) IBOutlet UITextView * logText;

- (IBAction)mailLog:(id)sender;
- (IBAction)toggleAdHoc:(id)sender;
- (IBAction)changeLogLevel:(id)sender;
- (IBAction)dismissSelf:(id)sender;
- (IBAction)toggleBreakEnabled:(id)sender;

@end
