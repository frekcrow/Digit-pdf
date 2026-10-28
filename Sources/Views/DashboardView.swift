import SwiftUI

/// Main dashboard view listing all generated documents with quick preview, search, filtering, and sharing.
public struct DashboardView: View {
    @EnvironmentObject private var fileManagerService: FileManagerService
    @StateObject private var viewModel = DashboardViewModel()

    public init() {}

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Format Filter Scroll Bar
                filterBarView

                // Main Content
                let items = viewModel.filteredDocuments(from: fileManagerService.documents)
                if items.isEmpty {
                    emptyStateView
                } else {
                    documentListView(items: items)
                }
            }
            .navigationTitle("TrollDocs")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Search by title or format..."
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 5) {
                        Image(systemName: "shield.checkerboard")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.accentColor)
                        Text("TrollStore")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.showingCreateSheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingCreateSheet) {
                CreateDocumentView()
                    .environmentObject(fileManagerService)
            }
            .sheet(item: $viewModel.previewItem) { item in
                QuickLookPreviewView(fileURL: item.fileURL)
            }
            .sheet(item: $viewModel.shareItem) { item in
                ShareSheetView(activityItems: [item.fileURL])
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Subviews

    /// Horizontal category filter bar
    private var filterBarView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" Filter Pill
                filterChip(
                    title: "All (\(fileManagerService.documents.count))",
                    icon: "tray.full.fill",
                    color: .accentColor,
                    isSelected: viewModel.selectedFormatFilter == nil
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedFormatFilter = nil
                    }
                }

                // Individual Format Pills
                ForEach(DocumentFormat.allCases) { format in
                    let count = fileManagerService.documents.filter { $0.format == format }.count
                    filterChip(
                        title: "\(format.shortName) (\(count))",
                        icon: format.systemIcon,
                        color: format.themeColor,
                        isSelected: viewModel.selectedFormatFilter == format
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedFormatFilter = format
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func filterChip(
        title: String,
        icon: String,
        color: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? color : Color(uiColor: .secondarySystemGroupedBackground))
            )
            .foregroundColor(isSelected ? .white : .primary)
            .overlay(
                Capsule()
                    .stroke(isSelected ? color : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// Document List with Swipe to Delete and Row Tap Preview
    private func documentListView(items: [DocumentItem]) -> some View {
        List {
            // Header stats section
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(items.count) Document\(items.count == 1 ? "" : "s") Available")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Total storage: \(fileManagerService.totalStorageSizeString)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "folder.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            // Documents section
            Section {
                ForEach(items) { item in
                    DocumentRowView(document: item) {
                        viewModel.shareItem = item
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.previewItem = item
                    }
                    .contextMenu {
                        Button {
                            viewModel.previewItem = item
                        } label: {
                            Label("Quick Look", systemImage: "eye")
                        }

                        Button {
                            viewModel.shareItem = item
                        } label: {
                            Label("Share Document", systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        Button(role: .destructive) {
                            try? fileManagerService.deleteDocument(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete { offsets in
                    fileManagerService.deleteDocuments(at: offsets, in: items)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .refreshable {
            fileManagerService.loadDocuments()
        }
    }

    /// Empty state placeholder view
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 90, height: 90)

                Image(systemName: viewModel.searchText.isEmpty ? "doc.badge.plus" : "doc.text.magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
            }

            VStack(spacing: 8) {
                Text(viewModel.searchText.isEmpty ? "No Documents Created Yet" : "No Matching Documents")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)

                Text(viewModel.searchText.isEmpty
                     ? "Create custom PDF, TXT, or CSV documents right on your device."
                     : "Check your search terms or select 'All' to view all documents.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            if viewModel.searchText.isEmpty {
                Button(action: {
                    viewModel.showingCreateSheet = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                        Text("Create First Document")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.top, 10)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
