import SwiftUI

struct SidebarView: View {
    @Binding var filter: PostFilter?
    let posts: [PostRecord]
    let showPublisherSettings: () -> Void

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
        .safeAreaInset(edge: .bottom) {
            Button("Publishing Settings", systemImage: "gearshape", action: showPublisherSettings)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
    }

    private func count(for filter: PostFilter) -> Int {
        switch filter {
        case .all: posts.count
        case .drafts: posts.count { $0.status == .draft }
        case .published: posts.count { $0.status == .published }
        }
    }
}
