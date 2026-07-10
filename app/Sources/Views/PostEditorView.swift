import SwiftData
import SwiftUI

struct PostEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var post: PostRecord
    @FocusState private var focusedField: Field?

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
                    Button("Share", systemImage: "square.and.arrow.up") {
                        // Sharing the public permalink will be enabled with Micropub sync.
                    }
                    .disabled(true)
                } else {
                    Button("Publish", systemImage: "paperplane.fill", action: publish)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.return, modifiers: .command)
                }
            }
        }
        .onAppear {
            if post.title.isEmpty && post.body.isEmpty {
                focusedField = .body
            }
        }
    }

    private func saveChanges() {
        post.modifiedAt = .now
        try? modelContext.save()
    }

    private func publish() {
        post.status = .published
        post.publishedAt = .now
        post.modifiedAt = .now
        try? modelContext.save()
    }
}
