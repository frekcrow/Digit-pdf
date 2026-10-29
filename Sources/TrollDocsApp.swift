import SwiftUI
import UIKit

@main
struct TrollDocsApp: App {
    @StateObject private var store = DocumentStore()

    init() {
        // SwiftUI lists paint an opaque table background on iOS 15. Clearing it
        // lets the paper stock show through everywhere.
        UITableView.appearance().backgroundColor = .clear
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(store)
                .tint(Theme.accent)
        }
    }
}
