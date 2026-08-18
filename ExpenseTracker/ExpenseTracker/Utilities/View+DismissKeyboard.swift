import SwiftUI

extension View {
    /// Dismisses the keyboard when the user taps anywhere in this view.
    /// Uses `simultaneousGesture` so it never blocks existing buttons, chips,
    /// or list-row taps elsewhere in the view — it just piggybacks on them.
    func dismissKeyboardOnTap() -> some View {
        // contentShape makes empty background area (gaps between stacked
        // controls, blank list space) hit-testable too, not just the controls
        // themselves — otherwise taps there wouldn't hit anything at all.
        contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
            )
    }
}
