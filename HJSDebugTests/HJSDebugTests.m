//
//  HJSDebugTests.m
//  HJSDebugTests
//
//  Created by Timothy Sanders on 2015-04-04.
//  Copyright (c) 2015 HIddenJester Software. All rights reserved.
//

@import XCTest;

@import HJSDebug;

@interface HJSDebugTests : XCTestCase

@end

@implementation HJSDebugTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    XCTAssert(YES, @"Pass");
}

- (void)testLogging {
	[[HJSDebugCenter defaultCenter] logMessage:@"Simple message logging test."];
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
