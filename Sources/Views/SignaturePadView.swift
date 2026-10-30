import SwiftUI
import PencilKit

/// Canvas view for capturing smooth handwritten signatures and initials.
struct SignaturePadView: View {
    var title: String = "Create Signature"
    var onSignatureCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var signatureName: String = "My Signature"
    @State private var shouldSaveToLibrary: Bool = true
    @State private var canvasView = PKCanvasView()
    @State private var hasDrawn: Bool = false
    @StateObject private var store = SignatureStore.shared

    var body: some View {
        NavigationView {
            ZStack {
                Theme.paper.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Name & Save Toggle
                    VStack(spacing: 12) {
                        HStack {
                            Text("Name:")
                                .font(Theme.sans(13, weight: .medium))
                                .foregroundColor(Theme.inkSecondary)
                            TextField("Signature Name", text: $signatureName)
                                .font(Theme.sans(14))
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(Theme.sheet)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Theme.rule, lineWidth: Theme.hairline)
                                )
                        }

                        Toggle(isOn: $shouldSaveToLibrary) {
                            Text("Save to Signature Library")
                                .font(Theme.sans(13))
                                .foregroundColor(Theme.ink)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 14)

                    Divider().background(Theme.rule)

                    // Signing Area
                    ZStack {
                        Theme.sheet

                        // Baseline rule
                        VStack {
                            Spacer()
                            HStack {
                                Text("X")
                                    .font(Theme.serif(18, weight: .bold))
                                    .foregroundColor(Theme.inkTertiary.opacity(0.6))
                                    .padding(.leading, 24)
                                Rectangle()
                                    .fill(Theme.ruleStrong.opacity(0.8))
                                    .frame(height: 1)
                                    .padding(.trailing, 24)
                            }
                            .padding(.bottom, 48)
                        }

                        SignatureCanvasRepresentable(canvasView: $canvasView, onStroke: {
                            hasDrawn = true
                        })
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(
                        Rectangle().stroke(Theme.rule, lineWidth: Theme.hairline)
                    )
                    .padding(16)

                    // Helper label
                    Text("Draw your signature using your finger or Apple Pencil above the line.")
                        .font(Theme.sans(11.5))
                        .foregroundColor(Theme.inkTertiary)
                        .padding(.bottom, 12)
                }
            }
            .navigationTitle(title)
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
                        canvasView.drawing = PKDrawing()
                        hasDrawn = false
                    }
                    .foregroundColor(Theme.inkSecondary)
                    .disabled(!hasDrawn)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitSignature()
                    }
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundColor(hasDrawn ? Theme.accent : Theme.inkTertiary)
                    .disabled(!hasDrawn)
                }
            }
        }
    }

    private func commitSignature() {
        let drawing = canvasView.drawing
        guard !drawing.bounds.isEmpty else { return }

        // Render transparent PNG
        let bounds = drawing.bounds.insetBy(dx: -12, dy: -12)
        let scale = UIScreen.main.scale
        let image = drawing.image(from: bounds, scale: scale)

        if shouldSaveToLibrary {
            store.save(image: image, name: signatureName.isEmpty ? "Signature" : signatureName)
        }

        onSignatureCaptured(image)
        dismiss()
    }
}

struct SignatureCanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var onStroke: () -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.tool = PKInkingTool(.pen, color: Theme.inkUIColor, width: 3.5)
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.delegate = context.coordinator
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.tool = PKInkingTool(.pen, color: Theme.inkUIColor, width: 3.5)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onStroke: onStroke)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var onStroke: () -> Void

        init(onStroke: @escaping () -> Void) {
            self.onStroke = onStroke
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            if !canvasView.drawing.bounds.isEmpty {
                onStroke()
            }
        }
    }
}
