import Foundation

/// Maps `[[type:id]]` type shorthands (e.g. `proj`) to their full canonical type value
/// (e.g. `project`). Any type used consistently works even without an explicit entry
/// here, since `expand` falls back to the input unchanged for unmapped shorthands.
enum TypeShorthand {
    private static let table: [String: String] = [
        "proj": "project"
    ]

    static func expand(_ shorthand: String) -> String {
        table[shorthand] ?? shorthand
    }
}
