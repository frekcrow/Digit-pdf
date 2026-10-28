import Foundation

/// Model representing a created document file stored in the app's directory.
public struct DocumentItem: Identifiable, Equatable, Hashable {
    public let id: UUID
    public let name: String
    public let format: DocumentFormat
    public let createdAt: Date
    public let fileURL: URL
    public let fileSize: Int64

    public init(
        id: UUID = UUID(),
        name: String,
        format: DocumentFormat,
        createdAt: Date = Date(),
        fileURL: URL,
        fileSize: Int64
    ) {
        self.id = id
        self.name = name
        self.format = format
        self.createdAt = createdAt
        self.fileURL = fileURL
        self.fileSize = fileSize
    }

    /// File title without file extension.
    public var titleWithoutExtension: String {
        fileURL.deletingPathExtension().lastPathComponent
    }

    /// Human-readable file size (e.g., "14.2 KB", "1.5 MB").
    public var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    /// Human-readable creation date and time.
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    /// Relative timestamp description (e.g. "Today, 10:45 AM").
    public var relativeDateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}
