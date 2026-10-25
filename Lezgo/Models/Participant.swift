import Foundation

public struct Participant: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public var isLeader: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        isLeader: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.isLeader = isLeader
    }
}
