import SwiftUI
import PencilKit
import PDFKit

/// Dedicated high-precision drawing canvas for annotating a specific PDF page with Apple Pencil or finger.
struct PageMarkupCanvasView: View {
    let page: PDFPage
    let pageIndex: Int
    var onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @State private var hasDrawn: Bool = false
    @State private var basePageImage: UIImage?

    var body: some View {
        NavigationView {
            ZStack {
                Theme.desk.ignoresSafeArea()

                GeometryReader { proxy in
                    let pageBounds = page.bounds(for: .mediaBox)
                    let fitSize = calculateFitSize(pageBounds: pageBounds.size, containerSize: proxy.size)

                    VStack {
                        Spacer()

                        ZStack {
                            // Base Page rendering
                            if let bg = basePageImage {
                                Image(uiImage: bg)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                ProgressView()
                            }

                            // Interactive PencilKit Canvas
                            PencilKitCanvasRepresentable(
                                canvasView: $canvasView,
                                toolPicker: toolPicker,
                                onDrawingChanged: {
                                    hasDrawn = !canvasView.drawing.bounds.isEmpty
                                }
                            )
                        }
                        .frame(width: fitSize.width, height: fitSize.height)
                        .background(Color.white)
                        .clipShape(Rectangle())
                        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Markup Page \(pageIndex + 1)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Theme.inkSecondary)
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        Haptics.destructive()
                        canvasView.drawing = PKDrawing()
                        hasDrawn = false
                    }
                    .foregroundColor(Theme.inkSecondary)
                    .disabled(!hasDrawn)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyDrawingToPage()
                    }
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundColor(Theme.accent)
                }
            }
            .onAppear(perform: prepareCanvas)
        }
    }

    private func calculateFitSize(pageBounds: CGSize, containerSize: CGSize) -> CGSize {
        let padding: CGFloat = 24
        let availW = max(100, containerSize.width - padding)
        let availH = max(100, containerSize.height - padding)

        let aspect = pageBounds.width / max(1, pageBounds.height)
        var w = availW
        var h = w / aspect

        if h > availH {
            h = availH
            w = h * aspect
        }

        return CGSize(width: w, height: h)
    }

    private func prepareCanvas() {
        let bounds = page.bounds(for: .mediaBox)
        let scale = UIScreen.main.scale
        let targetSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        self.basePageImage = page.thumbnail(of: targetSize, for: .mediaBox)
    }

    private func applyDrawingToPage() {
        let drawing = canvasView.drawing
        guard !drawing.bounds.isEmpty else {
            dismiss()
            return
        }

        let drawingImage = drawing.image(from: canvasView.bounds, scale: UIScreen.main.scale)

        PDFAnnotationHelper.addSignature(to: page, image: drawingImage, at: CGPoint(x: 0, y: 0))
        Haptics.success()
        onSaved()
        dismiss()
    }
}

struct PencilKitCanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    let toolPicker: PKToolPicker
    var onDrawingChanged: () -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.delegate = context.coordinator

        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChanged: onDrawingChanged)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var onDrawingChanged: () -> Void

        init(onDrawingChanged: @escaping () -> Void) {
            self.onDrawingChanged = onDrawingChanged
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onDrawingChanged()
        }
    }
}
