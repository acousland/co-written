import Foundation
import Security

struct AIReport: Decodable, Sendable {
    let summary: String
    let voice: String
    let formality: String
    let strengths: [String]
    let suggestions: [AISuggestion]
    let caveat: String
    func validate(passage: String) throws {
        guard [summary, voice, formality, caveat].allSatisfy({ !$0.isEmpty && $0.count <= 2_000 }),
              !strengths.isEmpty, strengths.count <= 6, strengths.allSatisfy({ !$0.isEmpty && $0.count <= 1_000 }),
              suggestions.count <= 6, suggestions.allSatisfy({ !$0.excerpt.isEmpty && $0.excerpt.count <= 500 && passage.contains($0.excerpt) && !$0.advice.isEmpty && $0.advice.count <= 1_000 }) else {
            throw AIClientError.invalidResponse
        }
    }
}
struct AISuggestion: Decodable, Sendable {
    let excerpt: String
    let advice: String
}
enum AIClientError: LocalizedError {
    case invalidEndpoint, missingToken, missingOpenAIKey, rejected(Int), invalidResponse, keychain(OSStatus)
    var errorDescription: String? {
        switch self {
        case .invalidEndpoint: return "Enter the HTTPS URL of your Co-written analysis server."
        case .missingToken: return "Save your personal Co-written access token in Settings. This is not an OpenAI key."
        case .missingOpenAIKey: return "Add your own OpenAI API key in Settings. It stays in your Mac’s Keychain."
        case .rejected(401): return "Your AI credential was not accepted. Check it in Settings."
        case .rejected(429): return "The AI service has reached a usage limit. Local analysis remains available."
        case .rejected: return "The AI service is unavailable. Try again later."
        case .invalidResponse: return "The AI service returned an unreadable result."
        case .keychain: return "Your AI credential could not be saved in the macOS Keychain."
        }
    }
}
enum SecureAIStore {
    private static let service = "au.com.acousland.CoWritten.ai-credential"
    private static func query(_ endpoint: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: endpoint]
    }
    static func load(endpoint: String) -> String? {
        var q = query(endpoint)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &value) == errSecSuccess, let data = value as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func exists(endpoint: String) -> Bool {
        var q = query(endpoint)
        q[kSecReturnAttributes as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        return SecItemCopyMatching(q as CFDictionary, &value) == errSecSuccess
    }
    static func save(_ token: String, endpoint: String) throws {
        let q = query(endpoint)
        guard !token.isEmpty else {
            let status = SecItemDelete(q as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw AIClientError.keychain(status) }
            return
        }
        let fields = [kSecValueData as String: Data(token.utf8)]
        var status = SecItemUpdate(q as CFDictionary, fields as CFDictionary)
        if status == errSecItemNotFound {
            var add = q.merging(fields) { _, new in new }
            add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(add as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw AIClientError.keychain(status) }
    }
}

enum AIClient {
    /// Credentials belong to a single canonical origin; changing the server requires a new token.
    static func endpoint(_ input: String) throws -> URL {
        guard var parts = URLComponents(string: input.trimmingCharacters(in: .whitespacesAndNewlines)),
              parts.scheme?.lowercased() == "https", let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              parts.path.isEmpty || parts.path == "/" else { throw AIClientError.invalidEndpoint }
        parts.scheme = "https"
        parts.host = host.lowercased()
        parts.path = "/v1/analyze"
        guard let url = parts.url else { throw AIClientError.invalidEndpoint }
        return url
    }
    static func tokenAccount(_ input: String) throws -> String {
        let url = try endpoint(input)
        return url.absoluteString
    }
    static func analyze(text: String, server: String) async throws -> AIReport {
        let url = try endpoint(server)
        guard let token = SecureAIStore.load(endpoint: url.absoluteString), !token.isEmpty else { throw AIClientError.missingToken }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 50
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["text": text])
        let data = try await send(request)
        let report = try JSONDecoder().decode(AIReport.self, from: data)
        try report.validate(passage: text)
        return report
    }
    static func send(_ request: URLRequest) async throws -> Data {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIClientError.invalidResponse }
        guard http.statusCode == 200 else { throw AIClientError.rejected(http.statusCode) }
        guard data.count <= 64_000 else { throw AIClientError.invalidResponse }
        return data
    }
}
private final class NoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
