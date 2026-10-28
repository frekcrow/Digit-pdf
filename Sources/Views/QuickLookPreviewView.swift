import SwiftUI
import QuickLook

/// A SwiftUI wrapper for Apple's native QLPreviewController.
public struct QuickLookPreviewView: UIViewControllerRepresentable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(fileURL: fileURL)
    }

    public func makeUIViewController(context: Context) -> UINavigationController {
        let previewController = QLPreviewController()
        previewController.dataSource = context.coordinator
        let nav = UINavigationController(rootViewController: previewController)
        return nav
    }

    public func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        if let previewController = uiViewController.viewControllers.first as? QLPreviewController {
            context.coordinator.fileURL = fileURL
            previewController.reloadData()
        }
    }

    public final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var fileURL: URL

        init(fileURL: URL) {
            self.fileURL = fileURL
        }

        public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return fileURL as NSURL
        }
    }
}
