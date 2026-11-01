//
//  RecordedRequest.swift
//  itsWrittenTests
//

import VoltaSDK

/// A prompt and history captured from a mock provider.
struct RecordedRequest: Sendable {
    let prompt: String
    let history: [ChatTurn]
}
