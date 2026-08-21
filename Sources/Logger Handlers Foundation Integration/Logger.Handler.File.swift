import Dispatch
public import Foundation
public import Logger_Handlers
public import Logging

extension Logger.Handler {

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

            do {
                try handle.write(contentsOf: Data((line(for: event, at: Date()) + "\n").utf8))
            } catch {

            }
        }
    }

    public func close() throws(CocoaError) {

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
