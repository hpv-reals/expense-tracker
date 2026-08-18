import SwiftUI

/// The app's 3 top-level destinations, driving both the floating tab bar and
/// which content is shown above it.
enum AppTab: CaseIterable {
    case home, reports, limits

    var title: String {
        switch self {
        case .home: return "Home"
        case .reports: return "Reports"
        case .limits: return "Limits"
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

    var body: some View {
        // Each tab applies the FloatingTabBar as its own `.safeAreaInset`
        // directly around its scrollable content (not once here, wrapping
        // all three) — a `.safeAreaInset` set outside a tab's own
        // NavigationStack doesn't reliably reach the List/ScrollView nested
        // inside it, which was letting the last rows of a long list sit
        // underneath the floating bar instead of stopping above it.
        ZStack {
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
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [Category.self, Transaction.self], inMemory: true)
}
