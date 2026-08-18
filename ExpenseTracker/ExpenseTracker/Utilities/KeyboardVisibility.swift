import Combine
import SwiftUI

/// Publishes whether the software keyboard is currently on screen, sourced
/// from `UIResponder`'s show/hide notifications — one signal usable by any
/// screen, regardless of which specific field triggered it (the amount
/// field's own `@FocusState` is private to `CurrencyAmountField`, so screens
/// hosting a `FloatingTabBar` need this instead of trying to plumb focus
/// state up from every possible input).
@MainActor
final class KeyboardVisibility: ObservableObject {
    @Published private(set) var isVisible = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { _ in true }
            .merge(with: NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification).map { _ in false })
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isVisible = $0 }
            .store(in: &cancellables)
    }
}

extension View {
    /// Fades this view out (and disables its hit-testing) while the keyboard
    /// is on screen. Used on `FloatingTabBar`: it sits in a `safeAreaInset`
    /// alongside scrollable content that itself keeps avoiding the keyboard
    /// normally, and that inset only ever gets pinned to whatever edge that
    /// content currently has — which, once the keyboard pushes everything up,
    /// is a thin sliver directly above the keyboard, not the actual screen
    /// edge. Simply hiding it there sidesteps that squeeze entirely, rather
    /// than trying to fight where a `safeAreaInset` places it.
    func hidesWhileKeyboardVisible(_ keyboard: KeyboardVisibility) -> some View {
        opacity(keyboard.isVisible ? 0 : 1)
            .allowsHitTesting(!keyboard.isVisible)
            .animation(.easeOut(duration: 0.2), value: keyboard.isVisible)
    }
}
