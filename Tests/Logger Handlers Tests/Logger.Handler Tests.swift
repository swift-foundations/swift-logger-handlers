// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-logger-handlers open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-logger-handlers
// project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Logging
import Synchronization
import Testing

@testable import Logger_Handlers

@Suite
struct `Logger.Handler Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `Logger.Handler Tests`.Unit {
    @Test
    func `composition uses the most permissive handler level`() {
        let first = Record()
        let second = Record()
        let handler =
            Recording(first, level: .debug)
            + Recording(second, level: .error)

        #expect(handler.logLevel == .debug)
    }
}

extension `Logger.Handler Tests`.`Edge Case` {
    @Test
    func `composition proxies metadata writes`() {
        let first = Record()
        let second = Record()
        var handler =
            Recording(first, level: .info)
            + Recording(second, level: .info)

        handler[metadataKey: "request"] = "123"

        #expect(handler[metadataKey: "request"] == "123")
    }
}

extension `Logger.Handler Tests`.Integration {
    @Test
    func `composition forwards one record to both handlers`() {
        let first = Record()
        let second = Record()
        let logger = Logger(label: "tests") { _ in
            Recording(first, level: .trace)
                + Recording(second, level: .trace)
        }

        logger.info("composed")

        #expect(first.messages.withLock { $0 } == ["composed"])
        #expect(second.messages.withLock { $0 } == ["composed"])
    }
}

private final class Record: Sendable {
    let messages = Mutex<[String]>([])
}

private struct Recording: LogHandler {
    let record: Record
    var metadata: Logger.Metadata = [:]
    var logLevel: Logger.Level

    init(_ record: Record, level: Logger.Level) {
        self.record = record
        self.logLevel = level
    }
}

extension Recording {
    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(event: LogEvent) {
        record.messages.withLock { $0.append(event.message.description) }
    }
}
