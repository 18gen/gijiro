import SwiftUI
import SwiftData

@main
struct GijiroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Meeting.self,
            TranscriptSegment.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 1000, height: 700)

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            for window in NSApp.windows {
                window.backgroundColor = NSColor(red: 33/255, green: 33/255, blue: 33/255, alpha: 1)
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            GoogleAuthService.shared.handleCallback(url: url)
        }
    }
}
