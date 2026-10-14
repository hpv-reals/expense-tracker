import Foundation

/// Curated icon (SF Symbols) and color (hex) choices offered when adding or
/// editing a category — the same values `DefaultDataSeeder` already uses for
/// the built-in categories, so a custom category can look just as "native"
/// as the presets.
enum CategoryStylePalette {
    static let icons: [String] = [
        "fork.knife", "car.fill", "bag.fill", "cart.fill", "bolt.fill",
        "gamecontroller.fill", "cross.case.fill", "stethoscope", "house.fill",
        "banknote.fill", "gift.fill", "creditcard.fill",
        "arrow.up.right.circle.fill", "arrow.down.left.circle.fill",
        "simcard.fill", "wifi", "phone.fill", "tv.fill",
        "chart.line.uptrend.xyaxis", "building.columns.fill", "drop.fill",
        "fuelpump.fill", "tray.and.arrow.down.fill", "sparkles",
        "cup.and.saucer.fill", "wrench.and.screwdriver.fill", "tshirt.fill",
        "graduationcap.fill", "heart.fill", "airplane", "pawprint.fill",
        "book.fill", "paintbrush.fill", "camera.fill", "leaf.fill",
        "flame.fill", "music.note", "figure.walk",
        "square.grid.2x2.fill", "ellipsis.circle.fill", "questionmark.circle"
    ]

    static let colors: [String] = [
        "#FF9500", "#FF3B30", "#FF2D55", "#FF375F", "#FF6961", "#FF6FB0",
        "#FF9F0A", "#FFCC00", "#FFD60A", "#E8601C",
        "#34C759", "#30D158", "#00A86B", "#5AC8A8", "#00C7BE",
        "#5AC8FA", "#32ADE6", "#40C8E0", "#64D2FF", "#007AFF",
        "#AF52DE", "#5856D6",
        "#A0714A", "#A2845E",
        "#8E8E93", "#98989D", "#6E6E73", "#48484A"
    ]
}
