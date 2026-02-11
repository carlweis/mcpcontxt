//
//  AuthenticationService.swift
//  MCPContxt
//
//  Triggers OAuth authentication for MCP servers using
//  OAuth 2.0 discovery, dynamic client registration, and PKCE
//

import Foundation
import AppKit
import Combine
import CryptoKit
import Network

class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()

    @Published var isAuthenticating = false
    @Published var authServerName: String?

    private init() {}

    // MARK: - OAuth Models

    private struct OAuthMetadata: Codable {
        let authorization_endpoint: String
        let token_endpoint: String
        let registration_endpoint: String?
        let scopes_supported: [String]?
        let code_challenge_methods_supported: [String]?
    }

    private struct ClientRegistration: Codable {
        let client_id: String
        let client_secret: String?
    }

    private struct TokenResponse: Codable {
        let access_token: String
        let token_type: String?
        let expires_in: Int?
        let refresh_token: String?
    }

    // MARK: - Public API

    /// Run the full OAuth flow: discover, register, open browser, wait for callback
    func authenticate(serverName: String, serverURL: String) async -> AuthResult {
        await MainActor.run {
            isAuthenticating = true
            authServerName = serverName
        }

        defer {
            Task { @MainActor in
                isAuthenticating = false
                authServerName = nil
            }
        }

        do {
            // 1. Discover OAuth metadata
            let metadata = try await discoverOAuthMetadata(serverURL: serverURL)

            // 2. Start local callback server
            let callbackServer = CallbackServer()
            let port = try await callbackServer.start()
            let redirectURI = "http://127.0.0.1:\(port)/callback"

            defer { callbackServer.stop() }

            // 3. Dynamic client registration
            let client = try await registerClient(metadata: metadata, redirectURI: redirectURI)

            // 4. Build authorization URL with PKCE
            let codeVerifier = generateCodeVerifier()
            let codeChallenge = generateCodeChallenge(from: codeVerifier)

            var components = URLComponents(string: metadata.authorization_endpoint)!
            components.queryItems = [
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "client_id", value: client.client_id),
                URLQueryItem(name: "redirect_uri", value: redirectURI),
                URLQueryItem(name: "code_challenge", value: codeChallenge),
                URLQueryItem(name: "code_challenge_method", value: "S256"),
            ]

            if let scopes = metadata.scopes_supported, !scopes.isEmpty {
                components.queryItems?.append(
                    URLQueryItem(name: "scope", value: scopes.joined(separator: " "))
                )
            }

            guard let authURL = components.url else {
                return .failed("Could not build authorization URL")
            }

            // 5. Open browser
            await MainActor.run {
                NSWorkspace.shared.open(authURL)
            }

            // 6. Wait for callback (up to 120 seconds)
            let code = try await callbackServer.waitForCode(timeout: 120)

            // 7. Exchange code for token
            _ = try await exchangeCodeForToken(
                metadata: metadata,
                client: client,
                code: code,
                redirectURI: redirectURI,
                codeVerifier: codeVerifier
            )

            // 8. Refresh Claude Code status
            await MCPStatusChecker.shared.refresh()

            return .success

        } catch let error as AuthError {
            print("[AuthenticationService] Auth error: \(error)")
            return .failed(error.localizedDescription)
        } catch {
            print("[AuthenticationService] Unexpected error: \(error)")
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - OAuth Flow Steps

    private func discoverOAuthMetadata(serverURL: String) async throws -> OAuthMetadata {
        guard let baseURL = URL(string: serverURL),
              let host = baseURL.host,
              let scheme = baseURL.scheme else {
            throw AuthError.invalidURL
        }

        let wellKnownURL = URL(string: "\(scheme)://\(host)/.well-known/oauth-authorization-server")!
        let (data, response) = try await URLSession.shared.data(from: wellKnownURL)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.discoveryFailed
        }

        return try JSONDecoder().decode(OAuthMetadata.self, from: data)
    }

    private func registerClient(metadata: OAuthMetadata, redirectURI: String) async throws -> ClientRegistration {
        guard let registrationURL = metadata.registration_endpoint.flatMap({ URL(string: $0) }) else {
            throw AuthError.registrationNotSupported
        }

        var request = URLRequest(url: registrationURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "client_name": "MCP Contxt",
            "redirect_uris": [redirectURI],
            "grant_types": ["authorization_code"],
            "response_types": ["code"],
            "token_endpoint_auth_method": "none"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.registrationFailed
        }

        return try JSONDecoder().decode(ClientRegistration.self, from: data)
    }

    private func exchangeCodeForToken(
        metadata: OAuthMetadata,
        client: ClientRegistration,
        code: String,
        redirectURI: String,
        codeVerifier: String
    ) async throws -> TokenResponse {
        guard let tokenURL = URL(string: metadata.token_endpoint) else {
            throw AuthError.invalidURL
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "grant_type=authorization_code",
            "code=\(code)",
            "redirect_uri=\(redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirectURI)",
            "client_id=\(client.client_id)",
            "code_verifier=\(codeVerifier)"
        ]
        request.httpBody = params.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.tokenExchangeFailed
        }

        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    // MARK: - PKCE

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Callback Server

/// Lightweight local HTTP server to capture OAuth callbacks
private class CallbackServer {
    private var listener: NWListener?
    private var continuation: CheckedContinuation<String, Error>?

    func start() async throws -> UInt16 {
        let params = NWParameters.tcp
        let listener = try NWListener(using: params, on: .any)

        self.listener = listener

        return try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if let port = listener.port {
                        print("[CallbackServer] Listening on port \(port.rawValue)")
                        continuation.resume(returning: port.rawValue)
                    }
                case .failed(let error):
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener.start(queue: DispatchQueue.global())
        }
    }

    func waitForCode(timeout: TimeInterval) async throws -> String {
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont

            // Timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak self] in
                self?.continuation?.resume(throwing: AuthError.timeout)
                self?.continuation = nil
            }
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: DispatchQueue.global())

        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            guard let data = data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }

            // Parse the HTTP request line: "GET /callback?code=xxx HTTP/1.1"
            let code = self?.extractCode(from: request)

            // Send response HTML
            let html: String
            if code != nil {
                html = """
                <html><body style="font-family:-apple-system;display:flex;justify-content:center;align-items:center;height:100vh;margin:0;background:#1a1a1a;color:#fff">
                <div style="text-align:center"><h1>Authentication Complete</h1><p>You can close this tab and return to MCP Contxt.</p></div>
                </body></html>
                """
            } else {
                html = """
                <html><body style="font-family:-apple-system;display:flex;justify-content:center;align-items:center;height:100vh;margin:0;background:#1a1a1a;color:#fff">
                <div style="text-align:center"><h1>Authentication Failed</h1><p>No authorization code received.</p></div>
                </body></html>
                """
            }

            let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n\(html)"
            connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })

            // Deliver the code
            if let code = code {
                self?.continuation?.resume(returning: code)
                self?.continuation = nil
            } else {
                self?.continuation?.resume(throwing: AuthError.noCodeReceived)
                self?.continuation = nil
            }
        }
    }

    private func extractCode(from request: String) -> String? {
        // Parse "GET /callback?code=xxx&state=yyy HTTP/1.1"
        guard let firstLine = request.components(separatedBy: "\r\n").first,
              let urlPart = firstLine.split(separator: " ").dropFirst().first,
              let components = URLComponents(string: String(urlPart)),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return nil
        }
        return code
    }
}

// MARK: - Result & Error Types

enum AuthResult {
    case success
    case failed(String)

    var succeeded: Bool {
        if case .success = self { return true }
        return false
    }

    var errorMessage: String? {
        if case .failed(let msg) = self { return msg }
        return nil
    }
}

enum AuthError: LocalizedError {
    case invalidURL
    case discoveryFailed
    case registrationNotSupported
    case registrationFailed
    case tokenExchangeFailed
    case timeout
    case noCodeReceived

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .discoveryFailed: return "Could not discover OAuth endpoints"
        case .registrationNotSupported: return "Server does not support dynamic client registration"
        case .registrationFailed: return "Client registration failed"
        case .tokenExchangeFailed: return "Token exchange failed"
        case .timeout: return "Authentication timed out"
        case .noCodeReceived: return "No authorization code received"
        }
    }
}
