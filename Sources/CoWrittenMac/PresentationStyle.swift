import SwiftUI

/// The paper presentation stays warm and readable in both system appearances.
/// Native window chrome and toolbar controls retain the system's Liquid Glass appearance.
enum PresentationStyle {
    static let ink = Color(red: 0.16, green: 0.21, blue: 0.19)
    static let accent = Color(red: 0.27, green: 0.40, blue: 0.31)
    static let secondary = Color(red: 0.40, green: 0.44, blue: 0.41)
    static let paper = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let card = Color.white.opacity(0.7)
    static let passage = Color.white.opacity(0.4)
}
