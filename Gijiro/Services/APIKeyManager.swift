import Foundation

enum APIKeyManager {
    nonisolated static var whisperAPIKey: String {
        UserDefaults.standard.string(forKey: "whisperAPIKey") ?? ""
    }

    nonisolated static var claudeAPIKey: String {
        UserDefaults.standard.string(forKey: "claudeAPIKey") ?? ""
    }

    nonisolated static var deepgramAPIKey: String {
        UserDefaults.standard.string(forKey: "deepgramAPIKey") ?? ""
    }
}
