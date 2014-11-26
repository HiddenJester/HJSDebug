//
//  UIApplication Utilities.swift
//  HJSKit
//
//  Created by Timothy Sanders on 2014-11-26.
//  Copyright (c) 2014 HiddenJester Software. All rights reserved.
//

/*!
Simple function that wraps around UIApplication to determine whether we have badge permissions.

:returns: true if we currently have badge permissions, false otherwise.
*/
public func hasBadgePermissions() -> Bool {
	return (UIApplication.sharedApplication().currentUserNotificationSettings().types & UIUserNotificationType.Badge)
		== UIUserNotificationType.Badge
}
