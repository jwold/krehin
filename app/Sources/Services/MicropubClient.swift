import Foundation

struct MicropubClient: Sendable {
    func publish(title: String, content: String, endpoint: String, token: String) async throws -> URL {
        guard let endpointURL = URL(string: endpoint),
              endpointURL.scheme == "https"
        else { throw MicropubError.invalidEndpoint }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "h", value: "entry"),
            URLQueryItem(name: "name", value: title),
            URLQueryItem(name: "content", value: content)
        ]
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MicropubError.invalidResponse
        }
        guard httpResponse.statusCode == 201 else {
            let message = Self.errorMessage(from: data)
            throw MicropubError.rejected(status: httpResponse.statusCode, message: message)
        }
        guard let location = httpResponse.value(forHTTPHeaderField: "Location"),
              let permalink = URL(string: location, relativeTo: endpointURL)?.absoluteURL
        else { throw MicropubError.missingPermalink }
        return permalink
    }

    func update(title: String, content: String, permalink: String, endpoint: String, token: String) async throws {
        try await mutate(
            fields: [
                URLQueryItem(name: "action", value: "update"),
                URLQueryItem(name: "url", value: permalink),
                URLQueryItem(name: "replace[name]", value: title),
                URLQueryItem(name: "replace[content]", value: content)
            ],
            endpoint: endpoint,
            token: token
        )
    }

    func delete(permalink: String, endpoint: String, token: String) async throws {
        try await mutate(
            fields: [
                URLQueryItem(name: "action", value: "delete"),
                URLQueryItem(name: "url", value: permalink)
            ],
            endpoint: endpoint,
            token: token
        )
    }

    private func mutate(fields: [URLQueryItem], endpoint: String, token: String) async throws {
        guard let endpointURL = URL(string: endpoint), endpointURL.scheme == "https" else {
            throw MicropubError.invalidEndpoint
        }
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = fields
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MicropubError.invalidResponse
        }
        guard httpResponse.statusCode == 204 else {
            throw MicropubError.rejected(status: httpResponse.statusCode, message: Self.errorMessage(from: data))
        }
    }

    private static func errorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)
        }
        return object["error_description"] as? String ?? object["error"] as? String
    }
}

private enum MicropubError: LocalizedError {
    case invalidEndpoint
    case invalidResponse
    case rejected(status: Int, message: String?)
    case missingPermalink

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            "The publishing endpoint is not a valid secure URL."
        case .invalidResponse:
            "The publishing server returned an invalid response."
        case .rejected(let status, let message):
            message ?? "The publishing server returned HTTP \(status)."
        case .missingPermalink:
            "The post was created, but the server did not return its permalink."
        }
    }
}
