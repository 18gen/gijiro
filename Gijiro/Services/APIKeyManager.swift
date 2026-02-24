import Foundation

enum APIKeyManager {
    static var whisperAPIKey: String {
        AppSettings.shared.whisperAPIKey
    }

    static var claudeAPIKey: String {
        AppSettings.shared.claudeAPIKey
    }

    static var deepgramAPIKey: String {
        AppSettings.shared.deepgramAPIKey
    }
}
