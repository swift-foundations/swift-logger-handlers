import Foundation
import Logger_Handlers
import Logging
import Testing

@testable import Logger_Handlers_Foundation_Integration

@Suite
struct `Logger.Handler.Console Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `Logger.Handler.Console Tests`.Unit {
    @Test
    func `initialization supplies handler defaults`() {
        let handler = Logger.Handler.Console(label: "tests")

        #expect(handler.logLevel == .info)
        #expect(handler.metadataProvider == nil)
        #expect(handler.metadata.isEmpty)
    }
}

extension `Logger.Handler.Console Tests`.`Edge Case` {
    @Test
    func `metadata supports replacement and removal`() {
        var handler = Logger.Handler.Console(label: "tests")

        handler.metadata = ["first": "1"]
        handler[metadataKey: "second"] = "2"
        handler[metadataKey: "first"] = nil

        #expect(handler.metadata == ["second": "2"])
    }
}

extension `Logger.Handler.Console Tests`.Integration {
    @Test
    func `line combines timestamp level source message and metadata`() {
        var handler = Logger.Handler.Console(
            label: "tests",
            metadataProvider: Logger.MetadataProvider {
                ["priority": "provider", "provider": "yes"]
            }
        )
        handler.metadata = ["priority": "stored", "stored": "yes"]

        let event = LogEvent(
            level: .info,
            message: "hello",
            metadata: ["explicit": "yes", "priority": "explicit"],
            source: "tests",
            file: "Tests.swift",
            function: "test",
            line: 42
        )
        let line = handler.line(
            for: event,
            at: Date(timeIntervalSince1970: 1_234_567_890.123)
        )

        #expect(
            line
                == "2009-02-13T23:31:30.123Z | INFO  | [tests:42] | hello | explicit=yes, priority=explicit, provider=yes, stored=yes"
        )
    }
}
