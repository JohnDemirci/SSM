//
//  isTesting.swift
//  SSM
//
//  Created by John Demirci on 9/4/25.
//

import Foundation

var isTesting: Bool {
    ProcessInfo.processInfo.isTesting
}

extension ProcessInfo {
    var isTesting: Bool {
        if environment.keys.contains("XCTestBundlePath") { return true }
        if environment.keys.contains("XCTestConfigurationFilePath") { return true }
        if environment.keys.contains("XCTestSessionIdentifier") { return true }
        
        return arguments.contains { argument in
            let path = URL(fileURLWithPath: argument)
            return path.lastPathComponent == "swiftpm-testing-helper" ||
            argument == "--testing-library" ||
            path.lastPathComponent == "xctest" ||
            path.pathExtension == "xctest"
        }
    }
}
