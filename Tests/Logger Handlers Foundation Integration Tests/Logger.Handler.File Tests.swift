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

import Foundation
import Logger_Handlers
import Logging
import Testing

@testable import Logger_Handlers_Foundation_Integration

@Suite
struct `Logger.Handler.File Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `Logger.Handler.File Tests`.Unit {
    @Test
    func `initialization supplies handler defaults`() {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString
        )
        let url = directory.appending(path: "unit.log")
        // swift-linter:disable:next try optional
        // REASON: Foundation.FileManager.removeItem(at:) is an untyped cross-module throwing API.
        defer { try? FileManager.default.removeItem(at: directory) }

        let handler: Logger.Handler.File
        do throws(CocoaError) {
            handler = try Logger.Handler.File(label: "tests", url: url)
        } catch {
            Issue.record("expected file handler initialization to succeed")
            return
        }

        #expect(handler.logLevel == .info)
        #expect(handler.metadataProvider == nil)
        #expect(handler.metadata.isEmpty)
    }
}

extension `Logger.Handler.File Tests`.`Edge Case` {
    @Test
    func `invalid parent path throws a Cocoa error`() {
        let parent = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString
        )
        #expect(FileManager.default.createFile(atPath: parent.path, contents: nil))
        // swift-linter:disable:next try optional
        // REASON: Foundation.FileManager.removeItem(at:) is an untyped cross-module throwing API.
        defer { try? FileManager.default.removeItem(at: parent) }

        #expect(throws: CocoaError.self) {
            try Logger.Handler.File(
                label: "tests",
                url: parent.appending(path: "log-handler-tests.log")
            )
        }
    }

    @Test
    func `close flushes pending writes and releases the file handle`() throws {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString
        )
        let url = directory.appending(path: "close.log")
        // swift-linter:disable:next try optional
        // REASON: Foundation.FileManager.removeItem(at:) is an untyped cross-module throwing API.
        defer { try? FileManager.default.removeItem(at: directory) }

        let handler = try Logger.Handler.File(label: "tests", url: url)
        handler.log(
            event: LogEvent(
                level: .info,
                message: "before close",
                metadata: nil,
                source: "tests",
                file: "Tests.swift",
                function: "test",
                line: 1
            )
        )

        try handler.close()

        let output = try String(contentsOf: url, encoding: .utf8)
        #expect(output.contains("before close"))
    }

    @Test
    func `logging after close is dropped instead of crashing the process`() throws {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString
        )
        let url = directory.appending(path: "post-close.log")
        // swift-linter:disable:next try optional
        // REASON: Foundation.FileManager.removeItem(at:) is an untyped cross-module throwing API.
        defer { try? FileManager.default.removeItem(at: directory) }

        let handler = try Logger.Handler.File(label: "tests", url: url)
        try handler.close()

        // Must not crash: before this fix, a write against an invalid/closed file
        // descriptor went through `FileHandle.write(_:)`, which can raise an
        // uncatchable Objective-C exception and take the whole process down.
        handler.log(
            event: LogEvent(
                level: .info,
                message: "after close",
                metadata: nil,
                source: "tests",
                file: "Tests.swift",
                function: "test",
                line: 2
            )
        )

        let output = try String(contentsOf: url, encoding: .utf8)
        #expect(!output.contains("after close"))
    }
}

extension `Logger.Handler.File Tests`.Integration {
    @Test
    func `record is appended with merged metadata`() {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString
        )
        let url = directory.appending(path: "integration.log")
        // swift-linter:disable:next try optional
        // REASON: Foundation.FileManager.removeItem(at:) is an untyped cross-module throwing API.
        defer { try? FileManager.default.removeItem(at: directory) }

        var handler: Logger.Handler.File
        do throws(CocoaError) {
            handler = try Logger.Handler.File(
                label: "tests",
                url: url,
                metadataProvider: Logger.MetadataProvider { ["provider": "yes"] }
            )
        } catch {
            Issue.record("expected file handler initialization to succeed")
            return
        }

        handler.metadata = ["stored": "yes"]
        handler.log(
            event: LogEvent(
                level: .info,
                message: "persisted",
                metadata: ["explicit": "yes"],
                source: "tests",
                file: "Tests.swift",
                function: "test",
                line: 42
            )
        )

        // swift-linter:disable:next try optional
        // REASON: Foundation.String(contentsOf:encoding:) is an untyped cross-module throwing API.
        guard let output = try? String(contentsOf: url, encoding: .utf8) else {
            Issue.record("expected file handler output to be readable")
            return
        }

        #expect(output.contains("[INFO ] persisted"))
        #expect(output.contains("explicit=yes, provider=yes, stored=yes"))
    }
}
