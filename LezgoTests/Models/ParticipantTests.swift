import Foundation
import Testing
@testable import Lezgo

struct ParticipantTests {
    @Test func ParticipantInitializesCorrectly() {
        let id = UUID()
        let participant = Participant(
            id: id,
            name: "John Doe",
            description: "Toyota Innova - B 1234 CD",
            isLeader: true
        )

        #expect(participant.id == id)
        #expect(participant.name == "John Doe")
        #expect(participant.description == "Toyota Innova - B 1234 CD")
        #expect(participant.isLeader == true)
    }

    @Test func ParticipantDefaultValues() {
        let participant = Participant(
            name: "Jane Smith",
            description: "Honda CR-V - B 5678 EF"
        )

        #expect(participant.isLeader == false)
        #expect(!participant.id.uuidString.isEmpty)
    }

    @Test func ParticipantEquatability() {
        let id = UUID()
        let p1 = Participant(id: id, name: "Driver", description: "Car", isLeader: false)
        let p2 = Participant(id: id, name: "Driver", description: "Car", isLeader: false)

        #expect(p1 == p2)
    }
}
