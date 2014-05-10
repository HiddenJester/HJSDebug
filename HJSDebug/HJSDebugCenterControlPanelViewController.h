//  Created by Timothy Sanders on 5/9/14.
//
//

#import <Foundation/Foundation.h>

@interface HJSDebugCenterControlPanelViewController : UIViewController

@property (nonatomic, weak) IBOutlet UITextView * logText;
@property (nonatomic, weak) IBOutlet UISwitch * adHocSwitch;
@property (nonatomic, weak) IBOutlet UISegmentedControl * loglevelSegmentedController;

- (IBAction)mailLog:(id)sender;
- (IBAction)toggleAdHoc:(id)sender;
- (IBAction)changeLogLevel:(id)sender;
- (IBAction)dismissSelf:(id)sender;

@end
