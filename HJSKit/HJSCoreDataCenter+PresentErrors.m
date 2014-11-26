//
//  HJSCoreDataCenter+PresentErrors.m
//  HJSKit
//
//  Created by Timothy Sanders on 2014-11-26.
//  Copyright (c) 2014 HiddenJester Software. All rights reserved.
//

#import "HJSKit.h"
#import "HJSCoreDataCenter+PresentErrors.h"

@implementation HJSCoreDataCenter (PresentErrors)

#pragma mark Public methods
- (void)presentErrorEmailFromViewController:(UIViewController *)presenter {
	HJSDebugCenter * debugCenter = [HJSDebugCenter defaultCenter];
	if ([debugCenter canSendMail]) {
		[debugCenter presentMailLogWithExplanation:self.errorEmailHeader
										   subject:self.errorEmailSubject
								fromViewController:presenter];
	}
	else {
		UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Data Error"
														 message:self.errorNoEmailAlertMessage
														delegate:nil
											   cancelButtonTitle:@"Dismiss"
											   otherButtonTitles:nil];
		[alert show];
	}
}

- (void)presentAlert {
	NSString * errorMessage = @"Please use the debug function to email the log as soon as possible.";
	UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Data Error"
													 message:errorMessage
													delegate:nil
										   cancelButtonTitle:@"Dismiss"
										   otherButtonTitles:nil];
	[alert show];
}

@end
