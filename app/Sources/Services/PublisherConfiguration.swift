import Foundation
import Observation

@MainActor
@Observable
final class PublisherConfiguration {
    static let defaultEndpoint = "https://krehin-publisher.joshua-wold.workers.dev/micropub"
    private static let endpointKey = "micropub-endpoint"

    var endpoint: String {
        didSet { UserDefaults.standard.set(endpoint, forKey: Self.endpointKey) }
    }

    var hasToken: Bool { !(KeychainStore.readToken() ?? "").isEmpty }

    init() {
        endpoint = UserDefaults.standard.string(forKey: Self.endpointKey) ?? Self.defaultEndpoint

        #if DEBUG
        if !hasToken,
           let bootstrapToken = ProcessInfo.processInfo.environment["KREHIN_MICROPUB_TOKEN"],
           !bootstrapToken.isEmpty {
            try? KeychainStore.saveToken(bootstrapToken)
        }
        #endif
    }

    func token() -> String { KeychainStore.readToken() ?? "" }

    func save(endpoint: String, token: String) throws {
        self.endpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        try KeychainStore.saveToken(token.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
