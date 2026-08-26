# swift-logger-handlers

[![CI](https://github.com/swift-compositions/swift-logger-handlers/actions/workflows/ci.yml/badge.svg)](https://github.com/swift-compositions/swift-logger-handlers/actions/workflows/ci.yml)
![Development Status](https://img.shields.io/badge/status-active--development-orange.svg)

Focused handlers and handler composition for
[swift-log](https://github.com/apple/swift-log).

## Products

| Product | Module | Purpose |
|---------|--------|---------|
| `Logger Handlers` | `Logger_Handlers` | Foundation-free `Logger.Handler` namespace and composition |
| `Logger Handlers Foundation Integration` | `Logger_Handlers_Foundation_Integration` | Console and file handlers backed by Foundation and Dispatch |

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-compositions/swift-logger-handlers.git", branch: "main")
]
```

Add the Foundation integration product when using the concrete handlers:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(
            name: "Logger Handlers Foundation Integration",
            package: "swift-logger-handlers"
        )
    ]
)
```

## Usage

```swift
import Foundation
import Logger_Handlers
import Logger_Handlers_Foundation_Integration
import Logging

let file = try Logger.Handler.File(
    label: "application",
    url: URL(fileURLWithPath: "/tmp/application.log")
)

let logger = Logger(label: "application") { label in
    Logger.Handler.Console(label: label) + file
}

logger.info("Application started")
```

`Logger.Handler.Console` writes UTC-timestamped records to standard error.
`Logger.Handler.File` appends records to the supplied file URL. The `+` operator
composes any two `Logging.LogHandler` values through swift-log's multiplex
handler.

## License

Licensed under the [Apache License, Version 2.0](LICENSE).
