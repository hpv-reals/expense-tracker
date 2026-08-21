import SwiftUI

/// The app's 3 top-level destinations, driving both the floating tab bar and
/// which content is shown above it.
enum AppTab: CaseIterable {
    case home, reports, limits

    var title: String {
        switch self {
        case .home: return "Home"
        case .reports: return "Reports"
        case .limits: return "Manage"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .reports: return "chart.pie.fill"
        case .limits: return "gauge.with.dots.needle.67percent"
        }
    }
}

struct RootTabView: View {
    @State private var selectedTab: AppTab = .home
    @StateObject private var keyboard = KeyboardVisibility()

    var body: some View {
        // Each tab still reserves space for the bar via its own
        // `.safeAreaInset` — a `.safeAreaInset` set outside a tab's own
        // NavigationStack doesn't reliably reach the List/ScrollView nested
        // inside it, which was letting the last rows of a long list sit
        // underneath the floating bar instead of stopping above it — but
        // that inset now holds an *invisible* placeholder (see
        // `FloatingTabBar.hiddenSpacer`) rather than a real, rendered bar.
        //
        // The one bar the user actually sees lives once, here, as a plain
        // overlay on top of the whole tab stack. Previously every tab drew
        // its own real `FloatingTabBar`, each with its own selection-highlight
        // `@Namespace`; switching tabs cross-faded between two independent
        // translucent capsules (each carrying its own `.ultraThinMaterial`
        // blur), which is what read as a "nháy" / flicker at the bar. With a
        // single shared instance, switching tabs just slides the highlight
        // within that one bar — no second bar ever fades in behind it.
        // `alignment: .bottom` — a plain `ZStack` centers its children, which
        // pinned the bar to the vertical middle of the screen instead of the
        // bottom edge, since `FloatingTabBar` only sizes itself to its own
        // content rather than filling the screen.
        ZStack(alignment: .bottom) {
            // All three tabs stay mounted (just hidden), matching native
            // TabView behavior — scroll position and in-progress state in a
            // background tab survive switching away and back.
            HomeView(selectedTab: $selectedTab)
                .opacity(selectedTab == .home ? 1 : 0)
                .allowsHitTesting(selectedTab == .home)
                .accessibilityHidden(selectedTab != .home)

            ReportsView(selectedTab: $selectedTab)
                .opacity(selectedTab == .reports ? 1 : 0)
                .allowsHitTesting(selectedTab == .reports)
                .accessibilityHidden(selectedTab != .reports)

            LimitsView(selectedTab: $selectedTab)
                .opacity(selectedTab == .limits ? 1 : 0)
                .allowsHitTesting(selectedTab == .limits)
                .accessibilityHidden(selectedTab != .limits)

            FloatingTabBar(selectedTab: $selectedTab)
                .hidesWhileKeyboardVisible(keyboard)
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [Category.self, Transaction.self, RecurringBill.self], inMemory: true)
}
