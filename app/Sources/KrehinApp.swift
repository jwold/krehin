import SwiftData
import SwiftUI

@main
struct KrehinApp: App {
    @State private var publisher = PublisherConfiguration()
    private let container: ModelContainer = {
        let configuration = ModelConfiguration("Krehin")
        return try! ModelContainer(for: PostRecord.self, configurations: configuration)
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(publisher)
                #if os(macOS)
                .frame(minWidth: 780, minHeight: 500)
                #endif
        }
        .modelContainer(container)
        #if os(macOS)
        .defaultSize(width: 1_180, height: 760)
        .windowResizability(.contentMinSize)
        #endif
    }
}
