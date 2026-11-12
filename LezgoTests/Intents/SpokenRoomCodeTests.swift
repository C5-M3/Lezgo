//
//  SpokenRoomCodeTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Testing
@testable import Lezgo

/// A room code said to Siri (`specs/UserStories.md` → US-08, "Join a trip"): six digits, however Siri wrote them down.
struct SpokenRoomCodeTests {
    @Test(arguments: [
        ("245245", "245245"),
        ("245 245", "245245"),
        ("2 4 5 2 4 5", "245245"),
        ("245-245", "245245"),
        ("two four five two four five", "245245"),
        ("Two four five, 245", "245245"),
        ("zero oh nine eight seven six", "009876"),
        ("Join 897654", "897654"),
        ("066335", "066335"),
        ("066 335", "066335"),
        ("zero six six three three five", "066335")
    ])
    func SixDigitsAreACode(spoken: String, code: String) {
        #expect(SpokenRoomCode.Parse(spoken) == code)
    }

    @Test(arguments: ["", "89765", "8976543", "two four five", "abcdef", "٨٩٧٦٥٤", "12 trips 3456 7"])
    func AnythingElseIsNotACode(spoken: String) {
        #expect(SpokenRoomCode.Parse(spoken) == nil)
    }
}
