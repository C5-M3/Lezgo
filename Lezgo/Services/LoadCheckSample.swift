#if DEBUG
/// One CloudKit request made during a load check: which call, how long it took, and its error code if it failed.
struct LoadCheckSample: Hashable {
    /// `fetch`, `query`, `save`, `delete` or `user`.
    var operation: String
    var duration: Duration
    /// The `CKError` code name, such as `requestRateLimited`, or `nil` when the request worked.
    var errorCode: String?

    init(operation: String, duration: Duration, errorCode: String? = nil) {
        self.operation = operation
        self.duration = duration
        self.errorCode = errorCode
    }
}
#endif
