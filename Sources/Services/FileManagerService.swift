import Foundation
import SwiftUI

public enum FileManagerServiceError: LocalizedError {
    case invalidFileName
    case fileAlreadyExists
    case writeFailed(String)
    case readFailed(String)
    case deleteFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidFileName:
            return "File name contains invalid characters."
        case .fileAlreadyExists:
            return "A file with this name already exists."
        case .writeFailed(let reason):
            return "Failed to save document: \(reason)"
        case .readFailed(let reason):
            return "Failed to read documents: \(reason)"
        case .deleteFailed(let reason):
            return "Failed to delete document: \(reason)"
        }
    }
}

/// Service managing document persistence in the app's standard Documents container.
public final class FileManagerService: ObservableObject {
    @Published public var documents: [DocumentItem] = []
    @Published public var errorMessage: String? = nil

    public let documentsDirectory: URL
    private let fileManager = FileManager.default

    public init() {
        guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Critical: Unable to locate app Documents directory.")
        }
        self.documentsDirectory = url

        // Ensure Documents directory exists
        if !fileManager.fileExists(atPath: documentsDirectory.path) {
            try? fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        }

        loadDocuments()
    }

    /// Reloads and publishes the list of stored documents.
    public func loadDocuments() {
        do {
            let resourceKeys: [URLResourceKey] = [
                .creationDateKey,
                .contentModificationDateKey,
                .fileSizeKey,
                .nameKey
            ]

            let fileURLs = try fileManager.contentsOfDirectory(
                at: documentsDirectory,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            )

            var items: [DocumentItem] = []

            for url in fileURLs {
                // Ignore directories or hidden system files
                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else {
                    continue
                }

                guard let format = DocumentFormat.from(url: url) else {
                    // Skip unsupported or foreign files
                    continue
                }

                let values = try? url.resourceValues(forKeys: Set(resourceKeys))
                let createdAt = values?.creationDate ?? values?.contentModificationDate ?? Date()
                let fileSize = Int64(values?.fileSize ?? 0)
                let fileName = url.lastPathComponent

                let item = DocumentItem(
                    name: fileName,
                    format: format,
                    createdAt: createdAt,
                    fileURL: url,
                    fileSize: fileSize
                )
                items.append(item)
            }

            // Sort newest first
            items.sort { $0.createdAt > $1.createdAt }

            DispatchQueue.main.async {
                self.documents = items
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load documents: \(error.localizedDescription)"
            }
        }
    }

    /// Saves a newly generated document file into the Documents folder.
    @discardableResult
    public func saveDocument(
        name: String,
        format: DocumentFormat,
        data: Data
    ) throws -> DocumentItem {
        let sanitizedBase = sanitizeFileName(name)
        guard !sanitizedBase.isEmpty else {
            throw FileManagerServiceError.invalidFileName
        }

        // Determine destination file URL
        let expectedExtension = format.fileExtension
        let finalFileName = sanitizedBase.hasSuffix(".\(expectedExtension)")
            ? sanitizedBase
            : "\(sanitizedBase).\(expectedExtension)"

        let fileURL = uniqueFileURL(for: finalFileName)

        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw FileManagerServiceError.writeFailed(error.localizedDescription)
        }

        // Fetch attributes of written file
        let attributes = (try? fileManager.attributesOfItem(atPath: fileURL.path)) ?? [:]
        let creationDate = (attributes[.creationDate] as? Date) ?? Date()
        let fileSize = (attributes[.size] as? Int64) ?? Int64(data.count)

        let document = DocumentItem(
            name: fileURL.lastPathComponent,
            format: format,
            createdAt: creationDate,
            fileURL: fileURL,
            fileSize: fileSize
        )

        loadDocuments()
        return document
    }

    /// Deletes a specific document file from disk.
    public func deleteDocument(_ item: DocumentItem) throws {
        do {
            if fileManager.fileExists(atPath: item.fileURL.path) {
                try fileManager.removeItem(at: item.fileURL)
            }
            loadDocuments()
        } catch {
            throw FileManagerServiceError.deleteFailed(error.localizedDescription)
        }
    }

    /// Deletes documents at indices matching a filtered list.
    public func deleteDocuments(at offsets: IndexSet, in list: [DocumentItem]) {
        for index in offsets {
            guard index < list.count else { continue }
            let item = list[index]
            try? deleteDocument(item)
        }
    }

    /// Formatted total storage consumed by all generated documents.
    public var totalStorageSizeString: String {
        let totalBytes = documents.reduce(0) { $0 + $1.fileSize }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytes)
    }

    // MARK: - Private Helpers

    private func sanitizeFileName(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "\\/:*?\"<>|")
        let cleaned = name.components(separatedBy: invalidChars).joined(separator: "_")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func uniqueFileURL(for fileName: String) -> URL {
        let targetURL = documentsDirectory.appendingPathComponent(fileName)
        if !fileManager.fileExists(atPath: targetURL.path) {
            return targetURL
        }

        let baseName = targetURL.deletingPathExtension().lastPathComponent
        let ext = targetURL.pathExtension
        var counter = 1

        while true {
            let candidateName = "\(baseName) (\(counter)).\(ext)"
            let candidateURL = documentsDirectory.appendingPathComponent(candidateName)
            if !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
            counter += 1
        }
    }
}
