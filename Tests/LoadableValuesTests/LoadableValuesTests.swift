//
//  LoadableValuesTests.swift
//  SSM
//
//  Created by John Demirci on 6/21/25.
//

import Foundation
import Testing
@testable import LoadableValues

@Suite("LoadableValuesTests")
struct LoadableValuesTests {
    private let testDate = Date(timeIntervalSince1970: 1000000)
    
    @Test("Testing the equality of the values", arguments: ["one", "two", "three"])
    func equality(_ value: String) {
        let date = Date.now

        let loadableValue1 = LoadableValue<String, Error>.loaded(
            LoadingSuccess(value: value, timestamp: date)
        )
        let loadableValue2 = LoadableValue<String, Error>.loaded(
            LoadingSuccess(value: value, timestamp: date)
        )
        
        #expect(loadableValue1 == loadableValue2)
    }
    
    @Test("Test idle state")
    func testIdleState() {
        let loadableValue = LoadableValue<String, TestError>.idle
        
        #expect(loadableValue.value == nil)
        #expect(loadableValue.failure == nil)
        #expect(!loadableValue.isLoading())
    }
    
    @Test("Test loading state")
    func testLoadingState() {
        let loadableValue = LoadableValue<String, TestError>.loading
        
        #expect(loadableValue.value == nil)
        #expect(loadableValue.failure == nil)
        #expect(loadableValue.isLoading())
    }
    
    @Test("Test loaded state")
    func testLoadedState() {
        let testValue = "test value"
        let loadableValue = LoadableValue<String, TestError>.loaded(
            LoadingSuccess(value: testValue, timestamp: testDate)
        )
        
        #expect(loadableValue.value == testValue)
        #expect(loadableValue.failure == nil)
        #expect(!loadableValue.isLoading())
    }
    
    @Test("Test failed state")
    func testFailedState() {
        let testError = TestError.testError
        let loadableValue = LoadableValue<String, TestError>.failed(
            LoadingFailure(failure: testError, timestamp: testDate)
        )
        
        #expect(loadableValue.value == nil)
        #expect(loadableValue.failure != nil)
        #expect(!loadableValue.isLoading())
    }
    
    @Test("Test equality for identical idle states")
    func testEqualityIdleStates() {
        let loadable1 = LoadableValue<String, TestError>.idle
        let loadable2 = LoadableValue<String, TestError>.idle
        
        #expect(loadable1 == loadable2)
    }
    
    @Test("Test equality for identical loading states")
    func testEqualityLoadingStates() {
        let loadable1 = LoadableValue<String, TestError>.loading
        let loadable2 = LoadableValue<String, TestError>.loading
        
        #expect(loadable1 == loadable2)
    }
    
    @Test("Test equality for identical loaded states")
    func testEqualityLoadedStates() {
        let success = LoadingSuccess(value: "test", timestamp: testDate)
        let loadable1 = LoadableValue<String, TestError>.loaded(success)
        let loadable2 = LoadableValue<String, TestError>.loaded(success)
        
        #expect(loadable1 == loadable2)
    }
    
    @Test("Test equality for identical failed states")
    func testEqualityFailedStates() {
        let failure = LoadingFailure(failure: TestError.testError, timestamp: testDate)
        let loadable1 = LoadableValue<String, TestError>.failed(failure)
        let loadable2 = LoadableValue<String, TestError>.failed(failure)
        
        #expect(loadable1 == loadable2)
    }
    
    @Test("Test inequality for different states")
    func testInequalityDifferentStates() {
        let idle = LoadableValue<String, TestError>.idle
        let loading = LoadableValue<String, TestError>.loading
        let loaded = LoadableValue<String, TestError>.loaded(
            LoadingSuccess(value: "test", timestamp: testDate)
        )
        let failed = LoadableValue<String, TestError>.failed(
            LoadingFailure(failure: TestError.testError, timestamp: testDate)
        )
        
        #expect(idle != loading)
        #expect(idle != loaded)
        #expect(idle != failed)
        #expect(loading != loaded)
        #expect(loading != failed)
        #expect(loaded != failed)
    }
    
    @Test("Test inequality for different loaded values")
    func testInequalityDifferentLoadedValues() {
        let loadable1 = LoadableValue<String, TestError>.loaded(
            LoadingSuccess(value: "test1", timestamp: testDate)
        )
        let loadable2 = LoadableValue<String, TestError>.loaded(
            LoadingSuccess(value: "test2", timestamp: testDate)
        )
        
        #expect(loadable1 != loadable2)
    }
    
    @Test("Test inequality for different failed values")
    func testInequalityDifferentFailedValues() {
        let loadable1 = LoadableValue<String, TestError>.failed(
            LoadingFailure(failure: TestError.testError, timestamp: testDate)
        )
        let loadable2 = LoadableValue<String, TestError>.failed(
            LoadingFailure(failure: TestError.anotherError, timestamp: testDate)
        )
        
        #expect(loadable1 != loadable2)
    }
    
    @Test("Test modify function with loaded state")
    func testModifyWithLoadedState() {
        var loadableValue = LoadableValue<String, TestError>.loaded(
            LoadingSuccess(value: "initial", timestamp: testDate)
        )
        
        loadableValue.modify { value in
            value = "modified"
        }
        
        #expect(loadableValue.value == "modified")
    }
    
    @Test("Test LoadingSuccess equatable")
    func testLoadingSuccessEquatable() {
        let success1 = LoadingSuccess(value: "test", timestamp: testDate)
        let success2 = LoadingSuccess(value: "test", timestamp: testDate)
        let success3 = LoadingSuccess(value: "different", timestamp: testDate)
        
        #expect(success1 == success2)
        #expect(success1 != success3)
    }
    
    @Test("Test LoadingFailure equatable")
    func testLoadingFailureEquatable() {
        let failure1 = LoadingFailure(failure: TestError.testError, timestamp: testDate)
        let failure2 = LoadingFailure(failure: TestError.testError, timestamp: testDate)
        let failure3 = LoadingFailure(failure: TestError.anotherError, timestamp: testDate)
        
        #expect(failure1 == failure2)
        #expect(failure1 != failure3)
    }
    
    @Test("Test LoadingSuccess hashable")
    func testLoadingSuccessHashable() {
        let success1 = LoadingSuccess(value: "test", timestamp: testDate)
        let success2 = LoadingSuccess(value: "test", timestamp: testDate)
        
        #expect(success1.hashValue == success2.hashValue)
    }
    
    @Test("Test LoadingFailure hashable")
    func testLoadingFailureHashable() {
        let failure1 = LoadingFailure(failure: TestError.testError, timestamp: testDate)
        let failure2 = LoadingFailure(failure: TestError.testError, timestamp: testDate)
        
        #expect(failure1.hashValue == failure2.hashValue)
    }
    
    @Test("Test LoadableValue hashable")
    func testLoadableValueHashable() {
        let loadable1 = LoadableValue<String, TestError>.loaded(
            LoadingSuccess(value: "test", timestamp: testDate)
        )
        let loadable2 = LoadableValue<String, TestError>.loaded(
            LoadingSuccess(value: "test", timestamp: testDate)
        )
        
        #expect(loadable1.hashValue == loadable2.hashValue)
    }
    
    @Test("Test codable encoding and decoding")
    func testCodable() throws {
        let originalValue = LoadableValue<String, TestError>.loaded(
            LoadingSuccess(value: "test", timestamp: testDate)
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalValue)
        
        let decoder = JSONDecoder()
        let decodedValue = try decoder.decode(LoadableValue<String, TestError>.self, from: data)
        
        #expect(originalValue == decodedValue)
    }

    @Test("Loadable value mapping a loaded value into another one")
    func testMappingLoadableValueAtLoadedState() {
        let date = Date()
        let value: Int = 5

        let loadableValueInt: LoadableValue<Int, TestError> = .loaded(
            LoadingSuccess<Int>(value: value, timestamp: date)
        )

        let loadableValueString = loadableValueInt.map {
            String($0)
        }

        #expect(loadableValueString.value == String(value))
    }

    @Test(
        "Using map on a LoadableValue without the loaded state returns the same state with different value generic",
        arguments: [
            LoadableValue<Int, Error>.loading,
            LoadableValue<Int, Error>.idle,
            LoadableValue<Int, Error>.cancelled(.now),
            LoadableValue<Int, Error>.failed(.init(failure: "", timestamp: .now))
        ]
    )
    func loadableValueMapWithOtherStates(_ state: LoadableValue<Int, Error>) async throws {
        let loadableValueString: LoadableValue<String, Error> = state.map {
            String($0)
        }

        #expect(loadableValueString.value == nil)

        switch state {
        case .idle:
            #expect(loadableValueString == .idle)
        case .loading:
            #expect(loadableValueString == .loading)
        case .loaded:
            #expect(Bool(false))
        case .failed(let failure):
            #expect(loadableValueString == .failed(failure))
        case .cancelled(let date):
            #expect(loadableValueString == .cancelled(date))
        }
    }

	@Test("why is this not working")
	func zipMultipleLoadableValues() async throws {
		let state1: LoadableValue<Int, Error> = .idle
		let state2: LoadableValue<String, Error> = .loading
		let zipped = zip(state1, state2)

		switch zipped {
		case .idle:
			#expect(Bool(true))
		default:
			#expect(Bool(false))
		}
	}
}

enum TestError: Error, Equatable, Hashable, Codable {
    case testError
    case anotherError
    
    var localizedDescription: String {
        switch self {
        case .testError:
            return "Test error"
        case .anotherError:
            return "Another error"
        }
    }
}

extension String: @retroactive Error {}
