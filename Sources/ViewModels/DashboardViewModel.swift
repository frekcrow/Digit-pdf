import SwiftUI
import Combine

/// View Model for managing dashboard presentation state, filtering, and user interactions.
public final class DashboardViewModel: ObservableObject {
    @Published public var searchText: String = ""
    @Published public var selectedFormatFilter: DocumentFormat? = nil
    @Published public var showingCreateSheet: Bool = false
    @Published public var previewItem: DocumentItem? = nil
    @Published public var shareItem: DocumentItem? = nil

    public init() {}

    /// Computes the filtered list of documents given the current search query and selected format.
    public func filteredDocuments(from allDocuments: [DocumentItem]) -> [DocumentItem] {
        return allDocuments.filter { item in
            let matchesFormat = (selectedFormatFilter == nil) || (item.format == selectedFormatFilter)
            let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            if trimmedSearch.isEmpty {
                return matchesFormat
            }

            let matchesName = item.name.lowercased().contains(trimmedSearch)
            let matchesExt = item.format.rawValue.lowercased().contains(trimmedSearch)

            return matchesFormat && (matchesName || matchesExt)
        }
    }
}
