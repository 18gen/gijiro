import Foundation
import AuthenticationServices
import CryptoKit
import Observation

@Observable
@MainActor
final class GoogleAuthService: NSObject {
    static let shared = GoogleAuthService()

    private let scope = "https://www.googleapis.com/auth/calendar.readonly"
    private let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!

    private let accessTokenKey = "google_access_token"
    private let refreshTokenKey = "google_refresh_token"
    private let expirationKey = "google_token_expiration"

    // Loopback redirect for Desktop OAuth clients
    private var loopbackPort: UInt16 = 0
    private var redirectURI: String { "http://127.0.0.1:\(loopbackPort)" }

    var isAuthenticated: Bool {
        KeychainService.loadToken(forKey: refreshTokenKey) != nil
    }

    private var clientID: String { AppSettings.shared.googleClientID }
    private var clientSecret: String { AppSettings.shared.googleClientSecret }

    private override init() {
        super.init()
    }

    func signIn() async throws {
        guard !clientID.isEmpty, !clientSecret.isEmpty else {
            throw AuthError.missingCredentials
        }

        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        // Start a temporary local HTTP server to receive the OAuth callback
        let (code, port) = try await startLoopbackServerAndAuthorize(
            codeChallenge: codeChallenge
        )
        loopbackPort = port

        try await exchangeCodeForTokens(code: code, codeVerifier: codeVerifier)
    }

    private func startLoopbackServerAndAuthorize(codeChallenge: String) async throws -> (code: String, port: UInt16) {
        // Create a socket on a random available port
        let serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else { throw AuthError.sessionFailed }

        var reuseAddr: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0 // Let OS assign a port
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.bind(serverSocket, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            close(serverSocket)
            throw AuthError.sessionFailed
        }

        // Get the assigned port
        var boundAddr = sockaddr_in()
        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &boundAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                getsockname(serverSocket, sockPtr, &addrLen)
            }
        }
        let port = UInt16(bigEndian: boundAddr.sin_port)
        loopbackPort = port

        Darwin.listen(serverSocket, 1)

        // Build auth URL with loopback redirect
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: "http://127.0.0.1:\(port)"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let authURL = components.url else {
            close(serverSocket)
            throw AuthError.invalidURL
        }

        // Open browser
        NSWorkspace.shared.open(authURL)

        // Wait for the callback on a background thread
        let authCode: String = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let clientSocket = accept(serverSocket, nil, nil)
                defer {
                    close(clientSocket)
                    close(serverSocket)
                }

                guard clientSocket >= 0 else {
                    continuation.resume(throwing: AuthError.noCallback)
                    return
                }

                // Read the HTTP request
                var buffer = [UInt8](repeating: 0, count: 4096)
                let bytesRead = recv(clientSocket, &buffer, buffer.count, 0)
                guard bytesRead > 0 else {
                    continuation.resume(throwing: AuthError.noCallback)
                    return
                }

                let requestString = String(bytes: buffer[0..<bytesRead], encoding: .utf8) ?? ""

                // Parse the code from the GET request: GET /?code=xxx&scope=... HTTP/1.1
                guard let firstLine = requestString.components(separatedBy: "\r\n").first,
                      let urlPart = firstLine.components(separatedBy: " ").dropFirst().first,
                      let queryComponents = URLComponents(string: "http://localhost\(urlPart)"),
                      let code = queryComponents.queryItems?.first(where: { $0.name == "code" })?.value else {
                    // Send error response
                    let errorHTML = """
                    HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n\
                    <html><body><h2>Authentication failed</h2><p>No authorization code received. You can close this tab.</p></body></html>
                    """
                    _ = errorHTML.withCString { send(clientSocket, $0, strlen($0), 0) }
                    continuation.resume(throwing: AuthError.noAuthCode)
                    return
                }

                // Send success response
                let successHTML = """
                HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n\
                <html><body><h2>Gijiro connected!</h2><p>You can close this tab and return to the app.</p></body></html>
                """
                _ = successHTML.withCString { send(clientSocket, $0, strlen($0), 0) }

                continuation.resume(returning: code)
            }
        }

        return (authCode, port)
    }

    func handleCallback(url: URL) {
        // No longer needed — using loopback server
    }

    private func exchangeCodeForTokens(code: String, codeVerifier: String) async throws {
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "code": code,
            "client_id": clientID,
            "client_secret": clientSecret,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": codeVerifier
        ]

        request.httpBody = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AuthError.tokenExchangeFailed(body)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let accessToken = json?["access_token"] as? String else {
            throw AuthError.noAccessToken
        }

        KeychainService.saveToken(accessToken, forKey: accessTokenKey)

        if let refreshToken = json?["refresh_token"] as? String {
            KeychainService.saveToken(refreshToken, forKey: refreshTokenKey)
        }

        if let expiresIn = json?["expires_in"] as? Int {
            let expiration = Date.now.addingTimeInterval(TimeInterval(expiresIn))
            KeychainService.saveToken(String(expiration.timeIntervalSince1970), forKey: expirationKey)
        }
    }

    func refreshAccessToken() async throws {
        guard let refreshToken = KeychainService.loadToken(forKey: refreshTokenKey) else {
            throw AuthError.noRefreshToken
        }

        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]

        request.httpBody = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            signOut()
            throw AuthError.tokenRefreshFailed(body)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let accessToken = json?["access_token"] as? String else {
            throw AuthError.noAccessToken
        }

        KeychainService.saveToken(accessToken, forKey: accessTokenKey)

        if let expiresIn = json?["expires_in"] as? Int {
            let expiration = Date.now.addingTimeInterval(TimeInterval(expiresIn))
            KeychainService.saveToken(String(expiration.timeIntervalSince1970), forKey: expirationKey)
        }
    }

    func getValidAccessToken() async throws -> String {
        if let expirationStr = KeychainService.loadToken(forKey: expirationKey),
           let expiration = Double(expirationStr),
           Date.now.timeIntervalSince1970 < expiration - 60,
           let token = KeychainService.loadToken(forKey: accessTokenKey) {
            return token
        }

        try await refreshAccessToken()

        guard let token = KeychainService.loadToken(forKey: accessTokenKey) else {
            throw AuthError.noAccessToken
        }
        return token
    }

    func signOut() {
        KeychainService.delete(key: accessTokenKey)
        KeychainService.delete(key: refreshTokenKey)
        KeychainService.delete(key: expirationKey)
    }

    // MARK: - PKCE helpers

    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64URLEncoded()
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .ascii) else { return verifier }
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncoded()
    }

    enum AuthError: Error, LocalizedError {
        case missingCredentials
        case invalidURL
        case noCallback
        case sessionFailed
        case noAuthCode
        case tokenExchangeFailed(String)
        case noAccessToken
        case noRefreshToken
        case tokenRefreshFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingCredentials: "Google Client ID or Secret not set"
            case .invalidURL: "Invalid auth URL"
            case .noCallback: "No callback received"
            case .sessionFailed: "Auth session failed to start"
            case .noAuthCode: "No authorization code in callback"
            case .tokenExchangeFailed(let msg): "Token exchange failed: \(msg)"
            case .noAccessToken: "No access token in response"
            case .noRefreshToken: "No refresh token available"
            case .tokenRefreshFailed(let msg): "Token refresh failed: \(msg)"
            }
        }
    }
}

// MARK: - Data base64url encoding
private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
