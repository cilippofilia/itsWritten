//
//  Recorder.swift
//  itsWrittenTests
//

import Synchronization

/// Thread-safe append-only log for values captured in `@Sendable` mock callbacks.
@available(iOS 26.0, *)
final class Recorder<Value: Sendable>: Sendable {
    private let storage = Mutex<[Value]>([])

    var values: [Value] {
        storage.withLock { $0 }
    }

    func append(_ value: Value) {
        storage.withLock { $0.append(value) }
    }
}
