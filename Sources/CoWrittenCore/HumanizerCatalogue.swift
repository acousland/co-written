import Foundation

public struct HumanizerPattern: Decodable, Sendable {
    public let id: Int
    public let name: String
    public let guidance: String
    public let weakAlone: Bool
}

/// Adapted from Humanizer 3.1.0, commit 225a6f39, MIT (Siqi Chen).
public enum HumanizerCatalogue {
    public static let patterns: [HumanizerPattern] = {
        let packaged = Bundle.main.resourceURL.flatMap { Bundle(url: $0.appendingPathComponent("CoWritten_CoWrittenCore.bundle")) }
        let url = (packaged ?? Bundle.module).url(forResource: "humanizer-patterns", withExtension: "json")
        guard let url, let data = try? Data(contentsOf: url),
              let patterns = try? JSONDecoder().decode([HumanizerPattern].self, from: data) else { return [] }
        return patterns
    }()
    public static var reviewInstructions: String {
        "Review using Humanizer 3.1.0's 26 editorial patterns (not an authorship classifier):\n" +
        patterns.map { "\($0.id). \($0.name): \($0.guidance)" }.joined(separator: "\n") +
        "\nOnly report supported patterns. Weak-alone patterns require a cluster of other cues. Leave deliberate voice, quotations, titles, proper names, code and text discussing a pattern alone. Do not rewrite the passage or invent facts."
    }
    public static func name(_ id: Int) -> String { patterns.first { $0.id == id }?.name ?? "Style pattern" }
}
