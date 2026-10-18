//
//  RecordedRequest.swift
//  itsWrittenTests
//

import VoltaSDK

/// A prompt and history captured from a mock provider.
@available(iOS 26.0, *)
struct RecordedRequest: Sendable {
    let prompt: String
    let history: [ChatTurn]
}
