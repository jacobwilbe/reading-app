import SwiftUI

@main
struct DailyReaderIOSApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var profileViewModel = ProfileViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(profileViewModel)
                .preferredColorScheme(profileViewModel.settings.theme.colorScheme)
        }
    }
}
