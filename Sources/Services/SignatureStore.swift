import Foundation
import UIKit
import Combine

struct SavedSignature: Identifiable, Equatable {
    let id: UUID
    var name: String
    let createdAt: Date
    let imageURL: URL

    var image: UIImage? {
        guard let data = try? Data(contentsOf: imageURL) else { return nil }
        return UIImage(data: data)
    }
}

final class SignatureStore: ObservableObject {
    static let shared = SignatureStore()

    @Published private(set) var signatures: [SavedSignature] = []

    private let fileManager = FileManager.default
    private let signaturesDirectory: URL

    init() {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        signaturesDirectory = support.appendingPathComponent("TrollDocs/Signatures", isDirectory: true)

        try? fileManager.createDirectory(at: signaturesDirectory, withIntermediateDirectories: true)
        loadSignatures()
    }

    func loadSignatures() {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: signaturesDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            signatures = []
            return
        }

        var loaded: [SavedSignature] = []
        for url in urls where url.pathExtension.lowercased() == "png" {
            let filename = url.deletingPathExtension().lastPathComponent
            let parts = filename.split(separator: "_")
            let id = parts.first.flatMap { UUID(uuidString: String($0)) } ?? UUID()
            let name = parts.count > 1 ? String(parts[1]) : "Signature"

            let attrs = try? fileManager.attributesOfItem(atPath: url.path)
            let date = attrs?[.creationDate] as? Date ?? Date()

            loaded.append(SavedSignature(id: id, name: name, createdAt: date, imageURL: url))
        }

        signatures = loaded.sorted(by: { $0.createdAt > $1.createdAt })
    }

    @discardableResult
    func save(image: UIImage, name: String = "Signature") -> SavedSignature? {
        guard let data = image.pngData() else { return nil }
        let id = UUID()
        let safeName = name.replacingOccurrences(of: "_", with: "-").replacingOccurrences(of: "/", with: "-")
        let filename = "\(id.uuidString)_\(safeName).png"
        let url = signaturesDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: url, options: .atomic)
            let newSig = SavedSignature(id: id, name: name, createdAt: Date(), imageURL: url)
            signatures.insert(newSig, at: 0)
            return newSig
        } catch {
            return nil
        }
    }

    func delete(_ signature: SavedSignature) {
        try? fileManager.removeItem(at: signature.imageURL)
        signatures.removeAll(where: { $0.id == signature.id })
    }
}
