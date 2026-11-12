//
//  SpokenRoomCode.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation

/// A room code said to Siri (`specs/UserStories.md` → US-08, "Join a trip"). Siri writes the same code down in many
/// ways: "245245", "245 245", "two four five two four five". Every digit is kept, other words are dropped, and the
/// result must be a valid room code.
enum SpokenRoomCode {
    /// Digit words Siri may write instead of digits; "oh" is how people often say zero.
    private static let words = [
        "zero": "0", "oh": "0", "one": "1", "two": "2", "three": "3", "four": "4",
        "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9"
    ]

    /// The six-digit room code in what was said, or `nil` when it does not hold exactly six digits.
    static func Parse(_ spoken: String) -> String? {
        let tokens = spoken.lowercased().split { $0.isLetter == false && $0.isNumber == false }
        let digits = tokens.map { token -> String in
            if token.allSatisfy({ $0.isASCII && $0.isNumber }) { return String(token) }
            return words[String(token)] ?? ""
        }
        .joined()
        return Trip.IsValidRoomCode(digits) ? digits : nil
    }
}
