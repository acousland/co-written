import Foundation
import Security
import LocalAuthentication

struct AIReport: Decodable, Sendable {
    let summary: String
    let voice: String
    let formality: String
    let strengths: [String]
    let suggestions: [AISuggestion]
    let caveat: String
    let aiWriting: AIWritingAssessment?
    var quickLook: AIQuickLook? = nil
    private func validateStructure() throws {
        guard [summary, voice, formality, caveat].allSatisfy({ !$0.isEmpty && $0.count <= 2_000 }),
              strengths.count <= 6, strengths.allSatisfy({ !$0.isEmpty && $0.count <= 1_000 }),
              suggestions.count <= 6 else { throw AIClientError.invalidAnalysis }
        if let aiWriting { try aiWriting.validateStructure() }
    }
    func validate(passage: String) throws {
        try validateStructure()
        guard suggestions.allSatisfy({ $0.isVerified(in: passage) }) else { throw AIClientError.invalidAnalysis }
        if let aiWriting { try aiWriting.validate(passage: passage) }
    }
    /// Keep useful analysis while omitting individual findings whose quoted evidence cannot be verified.
    func validated(passage: String) throws -> AIReport {
        try validateStructure()
        let verifiedSuggestions = suggestions.filter { $0.isVerified(in: passage) }
        let assessment = aiWriting?.validated(passage: passage)
        let omitted = suggestions.count - verifiedSuggestions.count + (aiWriting?.signals.count ?? 0) - (assessment?.signals.count ?? 0)
        let note = omitted == 0 ? caveat : Self.evidenceNote(caveat, omitted: omitted)
        let report = AIReport(summary: summary, voice: voice, formality: formality, strengths: strengths,
                              suggestions: verifiedSuggestions, caveat: note, aiWriting: assessment, quickLook: quickLook?.verified)
        try report.validate(passage: passage)
        return report
    }
    static func evidenceNote(_ original: String, omitted: Int) -> String {
        String(original.prefix(1_800)) + "\n\n\(omitted) finding\(omitted == 1 ? " was" : "s were") omitted because the quoted evidence could not be verified against this passage."
    }
}
struct AIQuickLook: Decodable, Sendable {
    let voice: String
    let formality: String
    let tone: String
    var verified: AIQuickLook? {
        [voice, formality, tone].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 64 && $0.split(whereSeparator: \.isWhitespace).count <= 8 } ? self : nil
    }
}
struct AIWritingAssessment: Decodable, Sendable {
    let summary: String
    let signals: [AIWritingSignal]
    let limitations: String
    fileprivate func validateStructure() throws {
        guard [summary, limitations].allSatisfy({ !$0.isEmpty && $0.count <= 2_000 }), signals.count <= 6
        else { throw AIClientError.invalidAnalysis }
    }
    func validate(passage: String) throws {
        try validateStructure()
        guard signals.allSatisfy({ $0.isVerified(in: passage) }) else { throw AIClientError.invalidAnalysis }
    }
    fileprivate func validated(passage: String) -> AIWritingAssessment {
        let verified = signals.filter { $0.isVerified(in: passage) }
        let omitted = signals.count - verified.count
        guard omitted > 0 else { return self }
        return AIWritingAssessment(summary: "Only observations with verified quoted evidence are shown.", signals: verified,
                                   limitations: AIReport.evidenceNote(limitations, omitted: omitted))
    }
}
struct AIWritingSignal: Decodable, Sendable {
    let patternID: Int
    let excerpt: String
    let reason: String
    let humanAlternative: String
    fileprivate func isVerified(in passage: String) -> Bool {
        (1...26).contains(patternID) && !excerpt.isEmpty && excerpt.count <= 500 && passage.contains(excerpt) &&
        !reason.isEmpty && reason.count <= 1_000 && !humanAlternative.isEmpty && humanAlternative.count <= 1_000
    }
}
struct AISuggestion: Decodable, Sendable {
    let excerpt: String
    let advice: String
    fileprivate func isVerified(in passage: String) -> Bool {
        !excerpt.isEmpty && excerpt.count <= 500 && passage.contains(excerpt) && !advice.isEmpty && advice.count <= 1_000
    }
}
enum AIClientError: LocalizedError, Equatable {
    case invalidEndpoint, missingToken, missingOpenAIKey, rejected(Int), invalidResponse, invalidAnalysis, keychain(OSStatus)
    case outputLimitReached, analysisRefused, analysisFiltered, analysisIncomplete, responseTooLarge
    var errorDescription: String? {
        switch self {
        case .invalidEndpoint: return "Enter the HTTPS URL of your Co-written analysis server."
        case .missingToken: return "Save your personal Co-written access token in Settings. This is not an OpenAI key."
        case .missingOpenAIKey: return "Add your own OpenAI API key in Settings. It stays in your Mac’s Keychain."
        case .rejected(401): return "Your AI credential was not accepted. Check it in Settings."
        case .rejected(429): return "The AI service has reached a usage limit. Local analysis remains available."
        case .rejected: return "The AI service is unavailable. Try again later."
        case .invalidResponse: return "The AI reply could not be read. Retry this passage; local analysis is still available."
        case .invalidAnalysis: return "The AI reply did not contain a usable analysis. Retry this passage; local analysis is still available."
        case .outputLimitReached: return "OpenAI stopped before completing the analysis because the reply reached its length limit. Try a shorter selection or retry."
        case .analysisRefused: return "OpenAI declined to analyse this passage. Your local analysis is still available."
        case .analysisFiltered: return "OpenAI's content filter interrupted this analysis. Your local analysis is still available."
        case .analysisIncomplete: return "OpenAI did not finish the analysis. Retry this passage; local analysis is still available."
        case .responseTooLarge: return "The AI reply was too large to process. Try a shorter selection."
        case .keychain: return "Your AI credential could not be saved in the macOS Keychain."
        }
    }
}
enum SecureAIStore {
    private static let service = "au.com.acousland.CoWritten.ai-credential"
    private static func query(_ endpoint: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: endpoint]
    }
    static func load(endpoint: String, allowInteraction: Bool = true) -> String? {
        var q = query(endpoint)
        if !allowInteraction {
            let context = LAContext()
            context.interactionNotAllowed = true
            q[kSecUseAuthenticationContext as String] = context
        }
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
        request.timeoutInterval = 75
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["text": text])
        let data = try await send(request)
        let report: AIReport
        do { report = try JSONDecoder().decode(AIReport.self, from: data) }
        catch { throw AIClientError.invalidAnalysis }
        return try report.validated(passage: text)
    }
    static func analysisFailure(code: String) -> AIClientError? {
        switch code {
        case "output_limit": return .outputLimitReached
        case "analysis_refused": return .analysisRefused
        case "content_filter": return .analysisFiltered
        case "analysis_incomplete": return .analysisIncomplete
        case "invalid_analysis": return .invalidAnalysis
        case "response_too_large": return .responseTooLarge
        default: return nil
        }
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
        guard http.statusCode == 200 else {
            if http.statusCode == 502, data.count <= 200_000,
               let code = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["code"] as? String,
               let error = analysisFailure(code: code) { throw error }
            throw AIClientError.rejected(http.statusCode)
        }
        guard data.count <= 200_000 else { throw AIClientError.responseTooLarge }
        return data
    }
}
private final class NoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
