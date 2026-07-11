import SwiftData
import SwiftUI

struct PostEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PublisherConfiguration.self) private var publisherConfiguration
    @Bindable var post: PostRecord
    let requestDelete: () -> Void
    @FocusState private var focusedField: Field?
    @State private var isPublishing = false
    @State private var showingPublisherSettings = false
    @State private var showingPublishError = false
    @State private var publishError = ""
    @AppStorage("show-post-titles") private var showPostTitles = false

    private var effectiveTitle: String { showPostTitles ? post.title : "" }

    private var hasUnpublishedChanges: Bool {
        effectiveTitle != post.lastPublishedTitle || post.body != post.lastPublishedBody
    }

    private enum Field {
        case title
        case body
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(
                    post.status == .draft ? "Draft" : "Published",
                    systemImage: post.status == .draft ? "doc.text" : "checkmark.circle.fill"
                )
                .foregroundStyle(post.status == .draft ? Color.secondary : Color.green)
                Spacer()
                Text(post.modifiedAt, format: .relative(presentation: .named))
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                if showPostTitles {
                    TextField("Optional title", text: $post.title, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 25, weight: .semibold))
                        .focused($focusedField, equals: .title)
                        .onChange(of: post.title) { saveChanges() }

                    Divider()
                }

                TextEditor(text: $post.body)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .focused($focusedField, equals: .body)
                    .onChange(of: post.body) { saveChanges() }
            }
            .padding(22)
        }
        .navigationTitle(post.displayTitle(showPostTitles: showPostTitles))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if post.status == .published {
                    if !post.remoteURL.isEmpty && hasUnpublishedChanges {
                        Button(action: startUpdating) {
                            if isPublishing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Update", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isPublishing || (post.body.isEmpty && (!showPostTitles || post.title.isEmpty)))
                    }
                    if let permalink = URL(string: post.remoteURL), !post.remoteURL.isEmpty {
                        ShareLink(item: permalink) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Label("Published", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button(action: startPublishing) {
                        if isPublishing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Publish", systemImage: "paperplane.fill")
                        }
                    }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.return, modifiers: .command)
                        .disabled(isPublishing || (post.body.isEmpty && (!showPostTitles || post.title.isEmpty)))
                }
                Button("Delete", systemImage: "trash", role: .destructive, action: requestDelete)
                    .disabled(isPublishing)
            }
        }
        .onAppear {
            if post.title.isEmpty && post.body.isEmpty {
                focusedField = .body
            }
        }
        .sheet(isPresented: $showingPublisherSettings) {
            AppSettingsView()
        }
        .alert("Couldn’t Publish", isPresented: $showingPublishError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(publishError)
        }
    }

    private func saveChanges() {
        post.modifiedAt = .now
        try? modelContext.save()
    }

    private func startPublishing() {
        guard publisherConfiguration.hasToken else {
            showingPublisherSettings = true
            return
        }
        Task { await publish() }
    }

    private func startUpdating() {
        guard publisherConfiguration.hasToken else {
            showingPublisherSettings = true
            return
        }
        Task { await update() }
    }

    @MainActor
    private func publish() async {
        isPublishing = true
        defer { isPublishing = false }

        do {
            let permalink = try await MicropubClient().publish(
                title: showPostTitles ? post.title : "",
                content: post.body,
                endpoint: publisherConfiguration.endpoint,
                token: publisherConfiguration.token()
            )
            post.status = .published
            post.publishedAt = .now
            post.modifiedAt = .now
            post.remoteURL = permalink.absoluteString
            post.lastPublishedTitle = effectiveTitle
            post.lastPublishedBody = post.body
            try modelContext.save()
        } catch {
            publishError = error.localizedDescription
            showingPublishError = true
        }
    }

    @MainActor
    private func update() async {
        isPublishing = true
        defer { isPublishing = false }

        do {
            try await MicropubClient().update(
                title: effectiveTitle,
                content: post.body,
                permalink: post.remoteURL,
                endpoint: publisherConfiguration.endpoint,
                token: publisherConfiguration.token()
            )
            post.lastPublishedTitle = effectiveTitle
            post.lastPublishedBody = post.body
            post.modifiedAt = .now
            try modelContext.save()
        } catch {
            publishError = error.localizedDescription
            showingPublishError = true
        }
    }
}
