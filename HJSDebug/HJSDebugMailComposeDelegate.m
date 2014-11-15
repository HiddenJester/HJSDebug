//  Created by Timothy Sanders on 5/9/14.
//
//

#import "HJSDebugMailComposeDelegate.h"

#import "HJSDebugCenter.h"

@implementation HJSDebugMailComposeDelegate

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
	NSString * mailResult;
	
	switch (result) {
		case MFMailComposeResultCancelled:
			mailResult = @"cancelled";
			break;
			
		case MFMailComposeResultSaved:
			mailResult = @"saved";
			break;

		case MFMailComposeResultSent:
			mailResult = @"sent";
			break;

		case MFMailComposeResultFailed:
			mailResult = @"failed";
			break;

		default:
			mailResult = @"unknown";
			break;
	}
	[[HJSDebugCenter defaultCenter] logAtLevel:HJSLogLevelDebug formatString:@"Mail log send attempted, the result was %@", mailResult];
	if (error) {
		[[HJSDebugCenter defaultCenter] logError:error];
	}
	[controller dismissViewControllerAnimated:YES completion:NULL];
}


@end
