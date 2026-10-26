/// A CloudKit record that is missing a field or holds a value the app cannot read.
///
/// It points to a schema mismatch (a field renamed in one container but not in `CloudKit/Schema.ckdb`) or to a
/// record written by an older build. `LiveTripService` skips such a record instead of crashing.
struct InvalidTripRecord: Error, Hashable {
    let recordType: String
    let field: String
}
