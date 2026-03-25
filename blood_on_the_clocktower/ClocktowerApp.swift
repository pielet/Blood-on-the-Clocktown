import SwiftUI

@main
struct ClocktowerApp: App {
    @StateObject private var game = ClocktowerGameViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(game)
        }
    }
}
