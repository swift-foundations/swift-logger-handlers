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

public import Logging

extension Logger {
    public enum Handler {}
}

/// Composes two handlers into a single handler that forwards records to both.
public func + <LHS: LogHandler, RHS: LogHandler>(
    lhs: LHS,
    rhs: RHS
) -> MultiplexLogHandler {
    MultiplexLogHandler([lhs, rhs])
}
