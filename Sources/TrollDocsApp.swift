import SwiftUI

@main
struct TrollDocsApp: App {
    @StateObject private var fileManagerService = FileManagerService()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(fileManagerService)
        }
    }
}
