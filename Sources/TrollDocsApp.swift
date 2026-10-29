import SwiftUI
import UIKit

@main
struct TrollDocsApp: App {
    @StateObject private var store = DocumentStore()
    @AppStorage("app_appearance") private var appearanceRaw: String = AppAppearance.system.rawValue

    private var currentAppearance: AppAppearance {
        AppAppearance(rawValue: appearanceRaw) ?? .system
    }

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
                .preferredColorScheme(currentAppearance.colorScheme)
                .onAppear {
                    AppAppearance.apply(style: currentAppearance.userInterfaceStyle)
                }
                .onChange(of: appearanceRaw) { newValue in
                    let newApp = AppAppearance(rawValue: newValue) ?? .system
                    AppAppearance.apply(style: newApp.userInterfaceStyle)
                }
        }
    }
}
