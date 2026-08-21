public import Logging

extension Logger {
    public enum Handler {}
}

public func + <LHS: LogHandler, RHS: LogHandler>(
    lhs: LHS,
    rhs: RHS
) -> MultiplexLogHandler {
    MultiplexLogHandler([lhs, rhs])
}
