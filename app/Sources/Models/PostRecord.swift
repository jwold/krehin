import Foundation
import SwiftData

enum PostStatus: String, Codable {
    case draft
    case published
}

@Model
final class PostRecord {
    var title: String
    var body: String
    var statusRawValue: String
    var createdAt: Date
    var modifiedAt: Date
    var publishedAt: Date?
    var externalURL: String
    var remoteURL: String = ""
    var lastPublishedTitle: String = ""
    var lastPublishedBody: String = ""

    init(
        title: String = "",
        body: String = "",
        status: PostStatus = .draft,
        createdAt: Date = .now,
        modifiedAt: Date = .now,
        publishedAt: Date? = nil,
        externalURL: String = "",
        remoteURL: String = "",
        lastPublishedTitle: String = "",
        lastPublishedBody: String = ""
    ) {
        self.title = title
        self.body = body
        self.statusRawValue = status.rawValue
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.publishedAt = publishedAt
        self.externalURL = externalURL
        self.remoteURL = remoteURL
        self.lastPublishedTitle = lastPublishedTitle
        self.lastPublishedBody = lastPublishedBody
    }

    var status: PostStatus {
        get { PostStatus(rawValue: statusRawValue) ?? .draft }
        set { statusRawValue = newValue.rawValue }
    }

    func displayTitle(showPostTitles: Bool) -> String {
        if showPostTitles {
            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanTitle.isEmpty { return cleanTitle }
        }
        let firstLine = body
            .split(whereSeparator: \Character.isNewline)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return firstLine.isEmpty ? "Untitled" : firstLine
    }

    var excerpt: String {
        body
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "> ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
