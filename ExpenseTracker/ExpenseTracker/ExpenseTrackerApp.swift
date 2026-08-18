import SwiftUI
import SwiftData

@main
struct ExpenseTrackerApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Category.self, Transaction.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .task {
                    DefaultDataSeeder.seedIfNeeded(context: container.mainContext)
                }
        }
        .modelContainer(container)
    }
}
