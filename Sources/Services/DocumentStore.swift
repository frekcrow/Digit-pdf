import Foundation
import Combine

enum DocumentStoreError: LocalizedError {
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .exportFailed(let reason):
            return "The document could not be written: \(reason)"
        }
    }
}

/// Owns the library of editable documents and their printed impressions.
///
/// Source documents live in Application Support (invisible to the Files app);
/// exports are written to Documents, where the Files app can see them.
final class DocumentStore: ObservableObject {
    @Published private(set) var documents: [Document] = []
    @Published var errorMessage: String?

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    let libraryDirectory: URL
    let documentsDirectory: URL

    init() {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        libraryDirectory = support.appendingPathComponent("TrollDocs/Library", isDirectory: true)
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? support

        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        try? fileManager.createDirectory(at: libraryDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)

        load()
    }

    // MARK: - Reading

    func load() {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: libraryDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        var loaded: [Document] = []
        for url in urls where url.pathExtension == "tdoc" {
            guard let data = try? Data(contentsOf: url) else { continue }
            if let document = try? decoder.decode(Document.self, from: data) {
                loaded.append(document)
            }
        }

        documents = loaded.sorted { $0.updatedAt > $1.updatedAt }
    }

    func document(withID id: UUID) -> Document? {
        documents.first { $0.id == id }
    }

    var totalWordCount: Int {
        documents.reduce(0) { $0 + $1.wordCount }
    }

    // MARK: - Writing

    func create(format: DocumentFormat = .pdf) -> Document {
        let document = Document(format: format)
        save(document)
        return documents.first { $0.id == document.id } ?? document
    }

    func save(_ document: Document) {
        var stored = document
        stored.updatedAt = Date()

        guard let data = try? encoder.encode(stored) else {
            errorMessage = "The document could not be encoded."
            return
        }

        do {
            try data.write(to: fileURL(for: stored.id), options: .atomic)
        } catch {
            errorMessage = "The document could not be saved: \(error.localizedDescription)"
            return
        }

        if let index = documents.firstIndex(where: { $0.id == stored.id }) {
            documents[index] = stored
        } else {
            documents.insert(stored, at: 0)
        }

        documents.sort { $0.updatedAt > $1.updatedAt }
    }

    func delete(_ document: Document) {
        try? fileManager.removeItem(at: fileURL(for: document.id))
        documents.removeAll { $0.id == document.id }
    }

    @discardableResult
    func duplicate(_ document: Document) -> Document {
        var copy = document
        copy.id = UUID()
        copy.title = "\(document.displayTitle) Copy"
        copy.createdAt = Date()
        copy.updatedAt = Date()
        save(copy)
        return documents.first { $0.id == copy.id } ?? copy
    }

    // MARK: - Exports

    /// Writes the document into the Documents directory, where it is visible in
    /// the Files app. Re-exporting the same document updates the same file.
    @discardableResult
    func export(_ document: Document) throws -> URL {
        let url = documentsDirectory.appendingPathComponent(document.fileName)
        do {
            let data = try DocumentRenderer.shared.data(for: document)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            throw DocumentStoreError.exportFailed(error.localizedDescription)
        }
    }

    /// A throwaway copy used only to hand to the share sheet.
    func temporaryExportURL(for document: Document) throws -> URL {
        let directory = fileManager.temporaryDirectory.appendingPathComponent("TrollDocsShare", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(document.fileName)
        do {
            let data = try DocumentRenderer.shared.data(for: document)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            throw DocumentStoreError.exportFailed(error.localizedDescription)
        }
    }

    // MARK: - Private

    private func fileURL(for id: UUID) -> URL {
        libraryDirectory.appendingPathComponent("\(id.uuidString).tdoc")
    }
}
