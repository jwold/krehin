import SwiftData
import SwiftUI

@main
struct KrehinApp: App {
    private let container: ModelContainer = {
        let configuration = ModelConfiguration("Krehin")
        return try! ModelContainer(for: PostRecord.self, configurations: configuration)
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
        #if os(macOS)
        .defaultSize(width: 1_180, height: 760)
        .windowResizability(.contentMinSize)
        #endif
    }
}
