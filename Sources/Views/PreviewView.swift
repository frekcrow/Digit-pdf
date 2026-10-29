import SwiftUI
import PDFKit

/// The printed result, shown over the writing desk.
struct PreviewView: View {
    let document: Document

    @EnvironmentObject private var store: DocumentStore
    @Environment(\.dismiss) private var dismiss

    @State private var data: Data?
    @State private var pageCount = 0
    @State private var errorMessage: String?
    @State private var shareURL: URL?
    @State private var showingShare = false

    var body: some View {
        ZStack {
            Theme.desk.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if let data = data {
                    PDFPreviewView(data: data)
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "doc.richtext")
                            .font(.system(size: 22, weight: .light))
                            .foregroundColor(Theme.inkTertiary)
                        Text(errorMessage ?? "Setting the pages...")
                            .font(Theme.sans(12))
                            .foregroundColor(Theme.inkSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear(perform: render)
        .sheet(isPresented: $showingShare) {
            if let url = shareURL {
                ShareSheetView(activityItems: [url])
            }
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .font(Theme.sans(10, weight: .semibold))
                        .tracking(1.5)
                        .foregroundColor(Theme.inkSecondary)
                }
                .buttonStyle(QuietButtonStyle())

                Spacer()

                VStack(spacing: 2) {
                    Text("Preview")
                        .font(Theme.serif(16))
                        .foregroundColor(Theme.ink)
                    Text("\(pageCount) \(pageCount == 1 ? "PAGE" : "PAGES")")
                        .font(Theme.mono(7.5, weight: .medium))
                        .tracking(1.2)
                        .foregroundColor(Theme.inkTertiary)
                }

                Spacer()

                Button {
                    shareDocument()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.inkSecondary)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(QuietButtonStyle())
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .background(Theme.paper)

            Hairline()
        }
    }

    private func render() {
        do {
            let rendered = try DocumentRenderer.shared.pdfData(for: document)
            data = rendered
            pageCount = PDFDocument(data: rendered)?.pageCount ?? 0
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func shareDocument() {
        do {
            let url = try store.temporaryExportURL(for: document)
            shareURL = url
            showingShare = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct PDFPreviewView: UIViewRepresentable {
    let data: Data

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.backgroundColor = Theme.deskUIColor
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.autoScales = true
        view.minScaleFactor = 0.2
        view.maxScaleFactor = 5
        view.document = PDFDocument(data: data)
        context.coordinator.data = data
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if context.coordinator.data != data {
            context.coordinator.data = data
            uiView.document = PDFDocument(data: data)
        }
    }

    final class Coordinator {
        var data: Data?
    }
}
