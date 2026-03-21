import SwiftUI

enum NodeColorPresets {
    static let presets: [(name: String, hex: String)] = [
        ("Green", "61BD4F"),
        ("Yellow", "F2D600"),
        ("Orange", "FF9F1A"),
        ("Red", "EB5A46"),
        ("Blue", "0079BF"),
    ]

    static func normalizedHex(_ hex: String) -> String {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        while h.hasPrefix("#") {
            h.removeFirst()
        }
        return h.uppercased()
    }

    /// Matches stored node hex (with or without `#`) to a preset, if any.
    static func preset(matchingStoredHex stored: String?) -> (name: String, hex: String)? {
        guard let stored else { return nil }
        let n = normalizedHex(stored)
        return presets.first { normalizedHex($0.hex) == n }
    }
}
