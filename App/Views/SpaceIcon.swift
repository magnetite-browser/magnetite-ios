import SwiftUI

/// A space's icon as the desktop draws it: one of its glyphs in the space's
/// colour. The desktop stores a glyph's name, or an imported icon name or
/// emoji that maps onto one (`Glyphs.tsx` in magnetite); another emoji shows
/// as it is, no icon as the title's first letter.
struct SpaceIcon: View {
    let space: Space
    var size: CGFloat = 18

    var body: some View {
        Group {
            if let symbol = Self.symbol(for: space.icon) {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.9, weight: .medium))
                    .foregroundStyle(space.tint ?? .accentColor)
            } else if let icon = space.icon, icon.unicodeScalars.contains(where: \.properties.isEmojiPresentation) {
                Text(icon)
                    .font(.system(size: size * 0.9))
            } else {
                Text(space.title.first.map { String($0).uppercased() } ?? "•")
                    .font(.system(size: size * 0.8, weight: .semibold, design: .rounded))
                    .foregroundStyle(space.tint ?? .accentColor)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// The SF Symbol in place of the desktop glyph `icon` names.
    static func symbol(for icon: String?) -> String? {
        guard let icon else { return nil }
        let lower = icon.lowercased()
        let name = glyphs[icon] != nil ? icon : aliases[lower] ?? (glyphs[lower] != nil ? lower : emoji[icon])
        return name.flatMap { glyphs[$0] }
    }

    private static let glyphs = [
        "bolt": "bolt", "home": "house", "briefcase": "briefcase", "book": "book", "code": "curlybraces",
        "globe": "globe", "heart": "heart", "star": "star", "music": "music.note", "cart": "cart",
        "camera": "camera", "flask": "flask", "leaf": "leaf", "flame": "flame", "chat": "message",
        "wrench": "wrench.adjustable", "compass": "location.north.circle", "folder": "folder",
        "plane": "airplane", "gamepad": "gamecontroller", "shield": "shield", "medical": "cross.case",
        // The phone's private space (the desktop draws a mask for its own).
        "mask": "theatermasks",
        "github": "arrow.triangle.branch", "diamond": "diamond", "circle": "circle", "square": "square",
        "triangle": "triangle",
    ]

    private static let aliases = [
        "flash": "bolt", "work": "briefcase", "terminal": "code", "gamecontroller": "gamepad",
        "paintbrush": "flame", "graduationcap": "book", "film": "camera", "airplane": "plane",
    ]

    private static let emoji = [
        "⚡": "bolt", "🏠": "home", "💼": "briefcase", "📚": "book", "🎨": "flame", "🎧": "music",
        "🛠️": "wrench", "🧪": "flask", "🌍": "globe", "🛒": "cart", "💬": "chat", "📷": "camera",
        "🎮": "gamepad", "✈️": "plane", "🌿": "leaf", "🔥": "flame", "💡": "bolt", "🧭": "compass",
        "🗂️": "folder", "✦": "star", "◆": "diamond", "●": "circle", "▲": "triangle", "■": "square",
        "🏥": "medical", "🐙": "github", "❤️": "heart", "⭐": "star",
    ]
}

extension RowItem {
    /// The page of a page row.
    var page: Page? {
        if case let .page(page) = self { page } else { nil }
    }
}

extension Space {
    /// The space's colour, for buttons and marks; none: the app's own.
    var tint: Color? {
        accent.map { Color(red: Double($0.red), green: Double($0.green), blue: Double($0.blue)) }
    }
}
