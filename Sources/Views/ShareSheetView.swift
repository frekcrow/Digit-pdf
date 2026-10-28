import SwiftUI
import UIKit

/// A SwiftUI wrapper around UIActivityViewController for native iOS file sharing.
public struct ShareSheetView: UIViewControllerRepresentable {
    public let activityItems: [Any]
    public let applicationActivities: [UIActivity]?

    public init(activityItems: [Any], applicationActivities: [UIActivity]? = nil) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
