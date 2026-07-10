import SwiftUI

struct SidebarView: View {
    @Binding var filter: PostFilter?
    let posts: [PostRecord]

    var body: some View {
        List(selection: $filter) {
            Section("Krehin") {
                ForEach(PostFilter.allCases) { item in
                    HStack(spacing: 8) {
                        Label(item.title, systemImage: item.systemImage)
                        Spacer(minLength: 8)
                        Text(count(for: item), format: .number)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .tag(item)
                }
            }

            Section("Collections") {
                Label("Link Posts", systemImage: "link")
                Label("Longform", systemImage: "text.alignleft")
            }
            .foregroundStyle(.secondary)
        }
        .navigationTitle("Krehin")
    }

    private func count(for filter: PostFilter) -> Int {
        switch filter {
        case .all: posts.count
        case .drafts: posts.count { $0.status == .draft }
        case .published: posts.count { $0.status == .published }
        }
    }
}
