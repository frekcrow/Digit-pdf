import Foundation
import Combine

/// Holds the working copy of a document while it is open and schedules a quiet
/// autosave, so the writer never has to think about a Save button.
final class EditorViewModel: ObservableObject {
    @Published var document: Document {
        didSet {
            if document != oldValue {
                scheduleSave()
            }
        }
    }

    private let store: DocumentStore
    private var pendingSave: DispatchWorkItem?

    init(document: Document, store: DocumentStore) {
        self.document = document
        self.store = store
    }

    func flush() {
        pendingSave?.cancel()
        pendingSave = nil
        store.save(document)
    }

    func discard() {
        pendingSave?.cancel()
        pendingSave = nil
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.pendingSave = nil
            self.store.save(self.document)
        }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }
}
