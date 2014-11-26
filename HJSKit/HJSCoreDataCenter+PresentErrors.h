//
//  HJSCoreDataCenter+PresentErrors.h
//  HJSKit
//
//  Created by Timothy Sanders on 2014-11-26.
//  Copyright (c) 2014 HiddenJester Software. All rights reserved.
//

@class HJSCoreDataCenter;

@interface HJSCoreDataCenter (PresentErrors)
/**
 This is a convenience method that will attempt to send an email containing the log. If mail cannot be sent it will
 present a modal alert dialog alerting the user a data error has occurred.

 @param presenter A View Controller that will present the mail dialog.

 @result The user is either presented an email to send or an alert dialog informing them there has been an error.
 */
- (void)presentErrorEmailFromViewController:(UIViewController *)presenter;

/**
 This presents an alert asking the user to email the log as soon as possible. HJSCoreDataCenter.save will call
 this if adhocDebugging is enabled and there is a save error.
 */
- (void)presentAlert;
@end
