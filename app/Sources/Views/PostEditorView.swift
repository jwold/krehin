import SwiftData
import SwiftUI

struct PostEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PublisherConfiguration.self) private var publisherConfiguration
    @Bindable var post: PostRecord
    @FocusState private var focusedField: Field?
    @State private var isPublishing = false
    @State private var showingPublisherSettings = false
    @State private var showingPublishError = false
    @State private var publishError = ""

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
                TextField("Optional title", text: $post.title, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 25, weight: .semibold))
                    .focused($focusedField, equals: .title)
                    .onChange(of: post.title) { saveChanges() }

                Divider()

                TextEditor(text: $post.body)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .focused($focusedField, equals: .body)
                    .onChange(of: post.body) { saveChanges() }
            }
            .padding(22)
        }
        .navigationTitle(post.displayTitle)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if post.status == .published {
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
                        .disabled(isPublishing || (post.title.isEmpty && post.body.isEmpty))
                }
            }
        }
        .onAppear {
            if post.title.isEmpty && post.body.isEmpty {
                focusedField = .body
            }
        }
        .sheet(isPresented: $showingPublisherSettings) {
            PublisherSettingsView()
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

    @MainActor
    private func publish() async {
        isPublishing = true
        defer { isPublishing = false }

        do {
            let permalink = try await MicropubClient().publish(
                title: post.title,
                content: post.body,
                endpoint: publisherConfiguration.endpoint,
                token: publisherConfiguration.token()
            )
            post.status = .published
            post.publishedAt = .now
            post.modifiedAt = .now
            post.remoteURL = permalink.absoluteString
            try modelContext.save()
        } catch {
            publishError = error.localizedDescription
            showingPublishError = true
        }
    }
}
