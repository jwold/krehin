import SwiftData
import SwiftUI

enum PostFilter: String, CaseIterable, Identifiable {
    case all
    case drafts
    case published

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All Posts"
        case .drafts: "Drafts"
        case .published: "Published"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "tray.full"
        case .drafts: "doc.text"
        case .published: "paperplane"
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PublisherConfiguration.self) private var publisherConfiguration
    @Query(sort: \PostRecord.modifiedAt, order: .reverse) private var posts: [PostRecord]

    @State private var filter: PostFilter? = .all
    @State private var selection: PersistentIdentifier?
    @State private var searchText = ""
    @State private var showingPublisherSettings = false
    @State private var deleteCandidate: PostRecord?
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var deleteError = ""
    @AppStorage("show-post-titles") private var showPostTitles = false

    private var visiblePosts: [PostRecord] {
        posts.filter { post in
            let matchesFilter = switch filter ?? .all {
            case .all: true
            case .drafts: post.status == .draft
            case .published: post.status == .published
            }
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty
                || post.title.localizedCaseInsensitiveContains(query)
                || post.body.localizedCaseInsensitiveContains(query)
            return matchesFilter && matchesSearch
        }
    }

    private var selectedPost: PostRecord? {
        posts.first { $0.persistentModelID == selection }
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                filter: $filter,
                posts: posts,
                showPublisherSettings: { showingPublisherSettings = true }
            )
                .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
        } content: {
            PostListView(
                title: (filter ?? .all).title,
                posts: visiblePosts,
                selection: $selection,
                searchText: $searchText,
                createPost: createPost,
                requestDelete: requestDelete
            )
            .navigationSplitViewColumnWidth(min: 280, ideal: 330, max: 420)
        } detail: {
            if let selectedPost {
                PostEditorView(post: selectedPost, requestDelete: { requestDelete(selectedPost) })
                    .id(selectedPost.persistentModelID)
            } else {
                ContentUnavailableView {
                    Label("Select a Post", systemImage: "doc.text")
                } description: {
                    Text("Choose a post from the index or create a new one.")
                } actions: {
                    Button("New Post", systemImage: "square.and.pencil", action: createPost)
                }
            }
        }
        .task {
            seedPostsIfNeeded()
            backfillPublishedBaselines()
            selectFirstVisiblePostIfNeeded()
        }
        .onChange(of: filter) {
            selectFirstVisiblePostIfNeeded()
        }
        .sheet(isPresented: $showingPublisherSettings) {
            AppSettingsView()
        }
        .confirmationDialog("Delete Post?", isPresented: $showingDeleteConfirmation, presenting: deleteCandidate) { post in
            Button("Delete", role: .destructive) {
                Task { await delete(post) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { post in
            if post.status == .published && !post.remoteURL.isEmpty {
                Text("This removes the post from the app and website.")
            } else {
                Text("This removes the post from this app.")
            }
        }
        .alert("Couldn’t Delete", isPresented: $showingDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError)
        }
    }

    private func createPost() {
        let post = PostRecord()
        modelContext.insert(post)
        try? modelContext.save()
        filter = .drafts
        selection = post.persistentModelID
    }

    private func requestDelete(_ post: PostRecord) {
        deleteCandidate = post
        showingDeleteConfirmation = true
    }

    @MainActor
    private func delete(_ post: PostRecord) async {
        do {
            if post.status == .published && !post.remoteURL.isEmpty {
                guard publisherConfiguration.hasToken else {
                    showingPublisherSettings = true
                    return
                }
                try await MicropubClient().delete(
                    permalink: post.remoteURL,
                    endpoint: publisherConfiguration.endpoint,
                    token: publisherConfiguration.token()
                )
            }
            if selection == post.persistentModelID { selection = nil }
            modelContext.delete(post)
            try modelContext.save()
            deleteCandidate = nil
            selectFirstVisiblePostIfNeeded()
        } catch {
            deleteError = error.localizedDescription
            showingDeleteError = true
        }
    }

    private func selectFirstVisiblePostIfNeeded() {
        if let selection, visiblePosts.contains(where: { $0.persistentModelID == selection }) {
            return
        }
        selection = visiblePosts.first?.persistentModelID
    }

    private func seedPostsIfNeeded() {
        guard posts.isEmpty else { return }
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: .now) ?? .now

        let examples = [
            PostRecord(
                title: "The interface should leave room for the thought",
                body: "That feels right. A tool can be opinionated without continually announcing its opinions.\n\n> The best writing environment is the one you stop noticing before the second sentence.",
                status: .published,
                publishedAt: .now
            ),
            PostRecord(
                title: "Publishing should feel like sending a message",
                body: "The web feels best when writing and publishing remain part of the same action.",
                status: .published,
                createdAt: yesterday,
                modifiedAt: yesterday,
                publishedAt: yesterday
            ),
            PostRecord(
                title: "A thought about small tools",
                body: "Tools should disappear into the work.",
                status: .draft,
                createdAt: yesterday,
                modifiedAt: .now
            ),
            PostRecord(
                title: "A linkblog is a useful shape for the small web",
                body: "Commentary and outbound links can share one quiet timeline.",
                status: .published,
                createdAt: yesterday,
                modifiedAt: yesterday,
                publishedAt: yesterday,
                externalURL: "https://daringfireball.net/linked/"
            )
        ]

        examples.forEach(modelContext.insert)
        try? modelContext.save()
    }

    private func backfillPublishedBaselines() {
        let published = posts.filter {
            $0.status == .published
                && !$0.remoteURL.isEmpty
                && $0.lastPublishedTitle.isEmpty
                && $0.lastPublishedBody.isEmpty
        }
        guard !published.isEmpty else { return }
        for post in published {
            post.lastPublishedTitle = showPostTitles ? post.title : ""
            post.lastPublishedBody = post.body
        }
        try? modelContext.save()
    }
}
