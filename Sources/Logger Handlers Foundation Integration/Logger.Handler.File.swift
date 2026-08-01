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

import Dispatch
public import Foundation
public import Logger_Handlers
public import Logging

extension Logger.Handler {
    /// A serial handler that appends records to a file.
    public struct File: Logging.LogHandler {
        private let handle: FileHandle
        private let queue: DispatchQueue
        private let formatter: DateFormatter
        private var storedMetadata: Logger.Metadata

        public var logLevel: Logger.Level
        public var metadataProvider: Logger.MetadataProvider?

        public init(
            label: String,
            url: URL,
            logLevel: Logger.Level = .info,
            metadataProvider: Logger.MetadataProvider? = nil
        ) throws(CocoaError) {
            let handle: FileHandle

            // swift-linter:disable:next do throws for typed catch
            // REASON: Foundation.FileManager/FileHandle throw untyped cross-module
            // errors here; the failure is normalized to CocoaError below.
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                if !FileManager.default.fileExists(atPath: url.path) {
                    _ = FileManager.default.createFile(atPath: url.path, contents: nil)
                }

                handle = try FileHandle(forWritingTo: url)
                _ = try handle.seekToEnd()
            } catch let error as CocoaError {
                throw error
            } catch {
                throw CocoaError(.fileWriteUnknown)
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"

            self.handle = handle
            self.queue = DispatchQueue(label: label)
            self.formatter = formatter
            self.storedMetadata = [:]
            self.logLevel = logLevel
            self.metadataProvider = metadataProvider
        }
    }
}

extension Logger.Handler.File {
    public var metadata: Logger.Metadata {
        get { queue.sync { storedMetadata } }
        set { queue.sync { storedMetadata = newValue } }
    }

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { queue.sync { storedMetadata[key] } }
        set { queue.sync { storedMetadata[key] = newValue } }
    }

    public func log(event: LogEvent) {
        queue.sync {
            // swift-linter:disable:next do throws for typed catch
            // REASON: Foundation.FileHandle.write(contentsOf:) is an untyped cross-module throwing API.
            do {
                try handle.write(contentsOf: Data((line(for: event, at: Date()) + "\n").utf8))
            } catch {
                // File-based logging is best-effort: a write failure (for example, a
                // closed or invalid file descriptor after `close()`) must never crash
                // the process. `FileHandle.write(_:)` could raise an uncatchable
                // Objective-C exception on failure; the throwing `write(contentsOf:)`
                // API lets us define the failure policy explicitly instead: drop the
                // record.
            }
        }
    }

    /// Flushes buffered data to disk and closes the underlying file handle.
    ///
    /// Call this when the handler is no longer needed to release the file descriptor
    /// deterministically, rather than relying on the handle being closed when the last
    /// reference is deallocated. Safe to call at most once; a second call throws
    /// because the handle is already closed.
    ///
    /// Calling ``log(event:)`` after `close()` is safe: per the error policy documented
    /// there, the resulting write failure is caught and the record is dropped rather
    /// than crashing.
    ///
    /// - Throws: ``CocoaError`` if the handle could not be flushed or closed.
    public func close() throws(CocoaError) {
        // DispatchQueue.sync(execute:) is `rethrows`, not typed-throws-generic, and
        // an explicit `throws(CocoaError)` annotation on the closure below crashes
        // the 6.3.3 compiler when nested inside this do/catch (toolchain defect,
        // not a source issue) — so the closure stays unannotated and the outer
        // do/catch re-normalizes whatever it throws.
        // swift-linter:disable:next do throws for typed catch
        // REASON: Dispatch.DispatchQueue.sync(execute:) is an untyped rethrows API
        // wrapping Foundation.FileHandle.synchronize()/close(), themselves untyped
        // cross-module throwing APIs.
        do {
            try queue.sync {
                try handle.synchronize()
                try handle.close()
            }
        } catch let error as CocoaError {
            throw error
        } catch {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    func line(for event: LogEvent, at date: Date) -> String {
        let timestamp = formatter.string(from: date)
        let level = event.level.rawValue.uppercased().padding(
            toLength: 5,
            withPad: " ",
            startingAt: 0
        )
        var line = "\(timestamp) [\(level)] \(event.message)"

        if let metadata = renderedMetadata(event.metadata) {
            line += " → \(metadata)"
        }

        return line
    }

    private func renderedMetadata(_ explicit: Logger.Metadata?) -> String? {
        var metadata = storedMetadata

        if let provided = metadataProvider?.get(), !provided.isEmpty {
            metadata.merge(provided) { _, new in new }
        }

        if let explicit, !explicit.isEmpty {
            metadata.merge(explicit) { _, new in new }
        }

        guard !metadata.isEmpty else { return nil }

        return
            metadata
            .sorted { $0.key < $1.key }
            .map { key, value in
                "\(key)=\(value)".replacingOccurrences(of: "\"", with: "")
            }
            .joined(separator: ", ")
    }
}
