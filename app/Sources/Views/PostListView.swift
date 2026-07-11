import SwiftData
import SwiftUI

struct PostListView: View {
    let title: String
    let posts: [PostRecord]
    @Binding var selection: PersistentIdentifier?
    @Binding var searchText: String
    let createPost: () -> Void
    let requestDelete: (PostRecord) -> Void

    var body: some View {
        List(posts, selection: $selection) { post in
            PostRowView(post: post)
                .tag(post.persistentModelID)
                .contextMenu {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        requestDelete(post)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        requestDelete(post)
                    }
                }
        }
        .overlay {
            if posts.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .navigationTitle(title)
        .searchable(text: $searchText, prompt: "Search posts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Post", systemImage: "square.and.pencil", action: createPost)
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

private struct PostRowView: View {
    let post: PostRecord
    @AppStorage("show-post-titles") private var showPostTitles = false

    private var rowTitle: String {
        post.displayTitle(showPostTitles: showPostTitles)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(rowTitle)
                    .font(.headline)
                    .lineLimit(2)
                if !post.externalURL.isEmpty {
                    Image(systemName: "arrow.up.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if !post.excerpt.isEmpty && post.excerpt != rowTitle {
                Text(post.excerpt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 5) {
                if post.status == .draft {
                    Text("Draft")
                        .foregroundStyle(.orange)
                    Text("·")
                }
                Text(post.modifiedAt, format: .relative(presentation: .named))
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 5)
    }
}
