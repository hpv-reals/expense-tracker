import SwiftUI

private struct TextSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

/// A numeric text field that displays a live-formatted currency amount as the
/// user types — thousands-grouped digits plus the locale's currency symbol
/// (e.g. "50.000 ₫" on a Vietnamese device). Backed by a plain `Double`.
///
/// VND (and every currency this app formats elsewhere, see `formattedCurrency`)
/// has no fractional unit, so input is restricted to whole-number digits.
///
/// Implementation note: the *editable* text field never shows the grouped
/// string ("50.000") — it stays a plain digit buffer (`rawDigits`, e.g.
/// "50000") that mirrors exactly what the user typed, with a separate `Text`
/// overlaid on top rendering the formatted version. Earlier this used a
/// single `TextField` whose bound string was rewritten with grouping dots
/// after every keystroke; feeding a differently-shaped string back into the
/// same field fights iOS's own cursor tracking, so a new digit could land
/// before *or* after previously-typed ones depending on exactly where the
/// (invisible, unformatted) caret ended up — typing "123" could just as
/// easily show up as "1230". Keeping the real input plain and un-rewritten
/// lets the native field track its own cursor correctly; only the read-only
/// overlay ever changes shape.
struct CurrencyAmountField: View {
    @Binding var amount: Double
    var placeholder: String = "0"
    var font: Font = .system(size: 44, weight: .bold, design: .rounded)
    var alignment: TextAlignment = .center

    /// Plain digits only, exactly as typed — never rewritten with grouping
    /// separators, so the field's own cursor tracking is never fought.
    @State private var rawDigits: String = ""
    @FocusState private var isFocused: Bool

    private var currencySymbol: String {
        Locale.current.currencySymbol ?? "₫"
    }

    private static let groupingFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private var formattedDisplay: String {
        amount > 0 ? (Self.groupingFormatter.string(from: NSNumber(value: amount)) ?? placeholder) : placeholder
    }

    /// The visible text's own rendered size, measured live so the invisible
    /// field below can be sized to exactly match it (see `body`) — an empty
    /// `TextField` otherwise collapses to a near-zero intrinsic width and only
    /// a couple of points near dead-center of the number are actually tappable.
    @State private var measuredTextSize: CGSize = .zero

    var body: some View {
        // The [number, symbol] pair is always sized to fit its own content,
        // then the surrounding spacers position that single unit within the
        // row per `alignment` — keeping the number and symbol glued together
        // instead of letting the text field stretch to fill the row and pull
        // the symbol away from it.
        HStack(spacing: 6) {
            if alignment != .leading { Spacer(minLength: 0) }

            ZStack {
                Text(formattedDisplay)
                    .font(font)
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: TextSizePreferenceKey.self, value: proxy.size)
                        }
                    )
                    .allowsHitTesting(false)

                // Invisible, sized to the visible text's measured frame (with a
                // floor so a lone "0" is still comfortably tappable) rather than
                // its own empty content, so a tap anywhere on the visible number
                // focuses this field.
                TextField("", text: $rawDigits)
                    .keyboardType(.numberPad)
                    .focused($isFocused)
                    .multilineTextAlignment(.trailing)
                    .font(font)
                    .foregroundStyle(.clear)
                    .tint(.clear)
                    .frame(
                        width: max(measuredTextSize.width, 44),
                        height: max(measuredTextSize.height, 44)
                    )
            }
            .fixedSize()
            .onPreferenceChange(TextSizePreferenceKey.self) { measuredTextSize = $0 }

            Text(currencySymbol)
                .font(font)
                .foregroundStyle(.secondary)

            if alignment != .trailing { Spacer(minLength: 0) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Amount")
        .accessibilityValue("\(formattedDisplay) \(currencySymbol)")
        .accessibilityAddTraits(.isKeyboardKey)
        .onAppear { syncRawDigits() }
        .onChange(of: amount) { _, newValue in syncRawDigits(from: newValue) }
        .onChange(of: rawDigits) { _, newValue in
            let digits = newValue.filter(\.isNumber)
            if digits != newValue {
                rawDigits = digits // strips anything non-digit (e.g. a paste); re-enters this handler with the clean value
            } else {
                amount = Double(digits) ?? 0
            }
        }
    }

    /// Mirrors `amount` into the plain-digit buffer. Safe to call unconditionally
    /// (including mid-typing, via the `amount` `onChange` above): the buffer this
    /// produces always matches what `rawDigits` already holds in that case, so
    /// SwiftUI treats it as a no-op and the user's in-progress input is undisturbed.
    private func syncRawDigits(from value: Double? = nil) {
        let value = value ?? amount
        // `String(format:)` rather than `String(Int(value))` — a stray huge
        // `amount` shouldn't be able to crash this by overflowing `Int`.
        rawDigits = value > 0 ? String(format: "%.0f", value) : ""
    }
}
