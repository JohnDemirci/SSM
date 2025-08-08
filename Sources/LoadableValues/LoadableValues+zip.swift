//
//  LoadableValues+zip.swift
//  SSM
//
//  Created by John Demirci on 8/7/25.
//

import Foundation

public func zip<each Value: Sendable, each Failure: Error>(
	_ loadableValues: repeat LoadableValue<each Value, each Failure>
) -> LoadableValue<(repeat each Value), ZippedError> {
	var failures: [Error] = []
	var failureTimestamps: [Date] = []
	var cancellations: [Date] = []
	var isIdle = false
	var isLoading = false
	var successTimestamps: [Date] = []

	for loadableValue in repeat each loadableValues {
		switch loadableValue {
		case .cancelled(let date):
			cancellations.append(date)
		case .failed(let loadingFailure):
			failures.append(loadingFailure.failure)
			failureTimestamps.append(loadingFailure.timestamp)
		case .loaded(let loadingSuccess):
			successTimestamps.append(loadingSuccess.timestamp)
		case .loading:
			isLoading = true
		case .idle:
			isIdle = true
		}
	}

	// guard checks based on priority
	guard failures.isEmpty else {
		let zippedError = ZippedError(errors: failures, timestamps: failureTimestamps)
		let minTimestamp = failureTimestamps.min() ?? Date()
		let loadingFailure = LoadingFailure(failure: zippedError, timestamp: minTimestamp)
		return .failed(loadingFailure)
	}

	guard !isIdle else {
		return .idle
	}

	guard cancellations.isEmpty else {
		return .cancelled(cancellations.min()!)
	}

	guard !isLoading else {
		return .loading
	}

	func extractValue<V, F: Error>(_ loadableValue: LoadableValue<V, F>) -> V {
		guard case .loaded(let success) = loadableValue else {
			fatalError("Expected loaded value")
		}
		return success.value
	}

	let resultTuple = (repeat extractValue(each loadableValues))
	let maxTimestamp = successTimestamps.max() ?? Date()

	let loadingSuccess = LoadingSuccess(
		value: resultTuple,
		timestamp: maxTimestamp
	)

	return .loaded(loadingSuccess)
}

public struct ZippedError: Error {
	let errors: [Error]
	let timestamps: [Date]

	init(
		errors: [Error],
		timestamps: [Date]
	) {
		self.errors = errors
		self.timestamps = timestamps
	}
}
