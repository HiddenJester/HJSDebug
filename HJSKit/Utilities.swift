//
//  Utilities.swift
//  HJSKit
//
//  Created by Timothy Sanders on 10/15/14.
//  Copyright (c) 2014 HiddenJester Software. All rights reserved.
//

import Foundation

/*!
	CGSize implementation of CGRectInset-like logic

	:param: size The original size to inset.
	:param: dx The amount to shrink the width. Negative values grow the width.
	:param: dy The amount to shrink the height. Negative values grow the height.
	
	:returns: An inset CGSize
*/
public func CGSizeInset(size: CGSize, dx: CGFloat, dy: CGFloat) -> CGSize {
	return CGSizeMake(size.width - dx, size.height - dy)
}

