import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            ReportsView()
                .tabItem { Label("Reports", systemImage: "chart.pie.fill") }

            LimitsView()
                .tabItem { Label("Limits", systemImage: "gauge.with.dots.needle.67percent") }
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [Category.self, Transaction.self], inMemory: true)
}
