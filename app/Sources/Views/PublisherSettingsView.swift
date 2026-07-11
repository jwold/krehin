import SwiftUI

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PublisherConfiguration.self) private var configuration

    @State private var endpoint = ""
    @State private var token = ""
    @State private var errorMessage = ""
    @State private var showingError = false
    @AppStorage("show-post-titles") private var showPostTitles = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Editor") {
                    Toggle("Show post titles", isOn: $showPostTitles)
                }

                Section("Micropub") {
                    TextField("Endpoint", text: $endpoint)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                    SecureField("Access token", text: $token)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                }

                Section {
                    Text("The token is stored in Apple Keychain and is never added to the project.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(endpoint.isEmpty || token.isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 320)
        #endif
        .onAppear {
            endpoint = configuration.endpoint
            token = configuration.token()
        }
        .alert("Couldn’t Save Settings", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func save() {
        do {
            try configuration.save(endpoint: endpoint, token: token)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}
