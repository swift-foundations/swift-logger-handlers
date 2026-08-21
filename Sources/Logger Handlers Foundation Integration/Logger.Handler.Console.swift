import Dispatch
import Foundation
public import Logger_Handlers
public import Logging

extension Logger.Handler {

    public struct Console: Logging.LogHandler {
        private let queue: DispatchQueue
        private let formatter: DateFormatter
        private var storedMetadata: Logger.Metadata

        public var logLevel: Logger.Level
        public var metadataProvider: Logger.MetadataProvider?

        public init(
            label: String,
            logLevel: Logger.Level = .info,
            metadataProvider: Logger.MetadataProvider? = nil
        ) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.locale = Locale(identifier: "en_US_POSIX")

            self.queue = DispatchQueue(label: label)
            self.formatter = formatter
            self.storedMetadata = [:]
            self.logLevel = logLevel
            self.metadataProvider = metadataProvider
        }
    }
}

extension Logger.Handler.Console {
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
                try FileHandle.standardError.write(
                    contentsOf: Data((line(for: event, at: Date()) + "\n").utf8)
                )
            } catch {

            }
        }
    }

    func line(for event: LogEvent, at date: Date) -> String {
        let components: [String?] = [
            formatter.string(from: date),
            format(event.level),
            "[\(event.source):\(event.line)]",
            event.message.description,
            renderedMetadata(event.metadata),
        ]

        return components.compactMap { $0 }.joined(separator: " | ")
    }

    private func format(_ level: Logger.Level) -> String {
        switch level {
        case .trace: "TRACE"
        case .debug: "DEBUG"
        case .info: "INFO "
        case .notice: "NOTCE"
        case .warning: "WARN "
        case .error: "ERROR"
        case .critical: "CRIT "
        }
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
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
    }
}
