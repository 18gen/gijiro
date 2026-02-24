import Foundation
import Observation

@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    var whisperAPIKey: String {
        didSet { defaults.set(whisperAPIKey, forKey: "whisperAPIKey") }
    }
    var claudeAPIKey: String {
        didSet { defaults.set(claudeAPIKey, forKey: "claudeAPIKey") }
    }
    var deepgramAPIKey: String {
        didSet { defaults.set(deepgramAPIKey, forKey: "deepgramAPIKey") }
    }
    var defaultToneMode: String {
        didSet { defaults.set(defaultToneMode, forKey: "defaultToneMode") }
    }
    var autoRecord: Bool {
        didSet { defaults.set(autoRecord, forKey: "autoRecord") }
    }
    var googleClientID: String {
        didSet { defaults.set(googleClientID, forKey: "googleClientID") }
    }
    var googleClientSecret: String {
        didSet { defaults.set(googleClientSecret, forKey: "googleClientSecret") }
    }
    var windowOpacity: Double {
        didSet {
            defaults.set(windowOpacity, forKey: "windowOpacity")
            NotificationCenter.default.post(name: .notepadOpacityChanged, object: nil)
        }
    }

    var hasWhisperKey: Bool { !whisperAPIKey.isEmpty }
    var hasClaudeKey: Bool { !claudeAPIKey.isEmpty }
    var hasDeepgramKey: Bool { !deepgramAPIKey.isEmpty }

    private init() {
        self.whisperAPIKey = defaults.string(forKey: "whisperAPIKey") ?? ""
        self.claudeAPIKey = defaults.string(forKey: "claudeAPIKey") ?? ""
        self.deepgramAPIKey = defaults.string(forKey: "deepgramAPIKey") ?? ""
        self.defaultToneMode = defaults.string(forKey: "defaultToneMode") ?? "business"
        self.autoRecord = defaults.bool(forKey: "autoRecord")
        self.googleClientID = defaults.string(forKey: "googleClientID") ?? ""
        self.googleClientSecret = defaults.string(forKey: "googleClientSecret") ?? ""
        self.windowOpacity = defaults.object(forKey: "windowOpacity") != nil
            ? defaults.double(forKey: "windowOpacity")
            : 1.0
    }
}

extension Notification.Name {
    static let notepadOpacityChanged = Notification.Name("notepadOpacityChanged")
}
