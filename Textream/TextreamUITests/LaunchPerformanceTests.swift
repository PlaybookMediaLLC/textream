//
//  LaunchPerformanceTests.swift
//  TextreamUITests
//
//  benchmarks/PLAN.md #8 with XCTest's launch metric (LaunchServices included,
//  unlike the desktop runner's `launch`, which execs the binary directly).
//

import XCTest

final class LaunchPerformanceTests: XCTestCase {
    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launch()
            app.terminate()
        }
    }
}
