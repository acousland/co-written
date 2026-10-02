import Foundation

/// Explicit developer check: only built-in synthetic writing is sent; output contains safe counts/status.
@MainActor enum AIValidation {
    static func run() async {
        guard let key = SecureAIStore.load(endpoint: DirectOpenAI.account, allowInteraction: false), !key.isEmpty else {
            print("AI check skipped: no OpenAI credential is available in this app's Keychain.")
            exit(2)
        }
        let text = "In today's rapidly evolving landscape, our team plays a crucial role in helping readers understand their writing. It's not just an application but also a companion for clearer communication. We tested the selection reader in our editor on Tuesday, and it returned the highlighted paragraph. The results were reviewed by two members of our team. Furthermore, the seamless integration unlocks potential across a diverse array of workflows, showcasing the project's pivotal role. Great question! At its core, what really matters is that you can see the words behind each observation. We want to explain uncertainty rather than pretend to know who wrote a passage. Let that sink in."
        print("AI check: one built-in English sample; credentials and reply content are not logged.")
        do {
            let data = try await AIClient.send(DirectOpenAI.request(text: text, key: key))
            print(diagnostics(data, passage: text))
            _ = try DirectOpenAI.decode(data, passage: text)
            print("AI check passed: response decoded and evidence validated.")
            exit(0)
        } catch {
            print("AI check failed: " + error.localizedDescription)
            exit(1)
        }
    }
    nonisolated static func diagnostics(_ data: Data, passage: String) -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "response=malformed_json" }
        let status = root["status"] as? String ?? "unknown"
        let safeStatus = ["completed", "incomplete", "failed", "cancelled", "queued", "in_progress"].contains(status) ? status : "unknown"
        let reason = (root["incomplete_details"] as? [String: Any])?["reason"] as? String
        let safeReason = ["max_output_tokens", "content_filter"].contains(reason ?? "") ? reason! : "none_or_other"
        let tokens = (root["usage"] as? [String: Any])?["output_tokens"] as? Int ?? 0
        var lines = ["response_status=\(safeStatus) incomplete_reason=\(safeReason) output_tokens=\(tokens) bytes=\(data.count)"]
        let output = root["output"] as? [[String: Any]] ?? []
        let content = output.filter { $0["type"] as? String == "message" }.flatMap { $0["content"] as? [[String: Any]] ?? [] }
        let text = content.filter { $0["type"] as? String == "output_text" }.compactMap { $0["text"] as? String }.joined()
        guard let report = try? JSONDecoder().decode(AIReport.self, from: Data(text.utf8)) else {
            lines.append("report_decoded=false refusal=\(content.contains { $0["type"] as? String == "refusal" })")
            return lines.joined(separator: "\n")
        }
        let signals = report.aiWriting?.signals ?? []
        lines.append("report_decoded=true suggestions=\(report.suggestions.count) unverified_suggestions=\(report.suggestions.filter { !passage.contains($0.excerpt) }.count) ai_signals=\(signals.count) unverified_signals=\(signals.filter { !passage.contains($0.excerpt) }.count)")
        return lines.joined(separator: "\n")
    }
}
