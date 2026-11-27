import Foundation
import Observation
import os

@Observable
@MainActor
public final class LocalLLMService {
    public static let shared = LocalLLMService()

    public var isGenerating: Bool = false
    public var isModelReady: Bool = false

    public struct ChatTurn: Sendable, Equatable {
        public let role: String
        public let content: String
    }

    public var conversationHistory: [ChatTurn] = []

    /// Discovers the bundled or local llama-cli binary dynamically without hardcoded user paths.
    public var binPath: String {
        if let resourceBin = Bundle.main.resourceURL?.appending(path: "bin/llama-cli").path,
           FileManager.default.isExecutableFile(atPath: resourceBin) {
            return resourceBin
        }
        let appSupportBin = URL.applicationSupportDirectory.appending(path: "Crucial/bin/llama-cli").path
        if FileManager.default.isExecutableFile(atPath: appSupportBin) {
            return appSupportBin
        }
        let packageBin = Self.packageRoot.appending(path: "bin/llama-b12633/llama-cli").path
        return packageBin
    }

    /// Discovers the bundled or local quantized GGUF model dynamically without hardcoded user paths.
    public var modelPath: String {
        if let resourceModel = Bundle.main.resourceURL?.appending(path: "models/llama-3.2-1b-instruct-q4_k_m.gguf").path,
           FileManager.default.fileExists(atPath: resourceModel) {
            return resourceModel
        }
        let appSupportModel = URL.applicationSupportDirectory.appending(path: "Crucial/models/llama-3.2-1b-instruct-q4_k_m.gguf").path
        if FileManager.default.fileExists(atPath: appSupportModel) {
            return appSupportModel
        }
        return Self.packageRoot.appending(path: "models/llama-3.2-1b-instruct-q4_k_m.gguf").path
    }

    private static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private init() {
        checkModelStatus()
    }

    public func clearConversationHistory() {
        conversationHistory.removeAll()
    }

    public func checkModelStatus() {
        let path = modelPath
        guard FileManager.default.fileExists(atPath: path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64,
              size > 700_000_000
        else {
            isModelReady = false
            return
        }
        isModelReady = true
    }

    public func streamFreeformAnswer(for query: String, onToken: @escaping @MainActor (String) -> Void) async -> String {
        checkModelStatus()
        guard isModelReady && FileManager.default.isExecutableFile(atPath: binPath) else {
            let synthesized = generateBuiltInTechnicalAnswer(for: query)
            onToken(synthesized)
            return synthesized
        }

        isGenerating = true
        defer { isGenerating = false }

        let systemPrompt = "You are Crucial Intelligence, an on-device macOS storage systems engineer. Provide direct, factual, structured answers regarding macOS filesystems, APFS, build caches, and storage maintenance. Do not use emojis or filler."
        var prompt = "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\(systemPrompt)<|eot_id|>"
        for turn in conversationHistory.suffix(4) {
            prompt += "<|start_header_id|>\(turn.role)<|end_header_id|>\n\(turn.content)<|eot_id|>"
        }
        prompt += "<|start_header_id|>user<|end_header_id|>\n\(query)<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n"

        let args = llamaArguments(prompt: prompt, maxTokens: 400)
        let buffer = OSAllocatedUnfairLock(initialState: "")
        let headerPassed = OSAllocatedUnfairLock(initialState: false)

        _ = await SubprocessRunner.stream(executable: binPath, arguments: args) { chunk in
            let delta = buffer.withLock { acc -> String? in
                acc += chunk
                let alreadyPassed = headerPassed.withLock { $0 }
                if !alreadyPassed {
                    if let range = acc.range(of: "<|start_header_id|>assistant<|end_header_id|>", options: .backwards) {
                        headerPassed.withLock { $0 = true }
                        return String(acc[range.upperBound...]).replacing("Exiting...", with: "")
                    } else if let marker = acc.range(of: "> ", options: .backwards) {
                        headerPassed.withLock { $0 = true }
                        return String(acc[marker.upperBound...]).replacing("Exiting...", with: "")
                    }
                    return nil
                } else {
                    return chunk.replacing("Exiting...", with: "")
                }
            }

            if let delta, !delta.isEmpty {
                Task { @MainActor in
                    onToken(delta)
                }
            }
        }

        let finalRaw = buffer.withLock { $0 }
        let cleanText = extractAssistantOutput(from: finalRaw)
        let result = cleanText.isEmpty ? generateBuiltInTechnicalAnswer(for: query) : cleanText

        conversationHistory.append(ChatTurn(role: "user", content: query))
        conversationHistory.append(ChatTurn(role: "assistant", content: result))
        return result
    }

    public func generateDeepExplanation(for item: FileItem) async -> String {
        let profile = await FileDiagnosticEngine.shared.profile(item: item)
        checkModelStatus()

        var llmInsight: String? = nil
        if isModelReady && FileManager.default.isExecutableFile(atPath: binPath) {
            isGenerating = true
            let response = await runLlamaInference(profile: profile)
            isGenerating = false
            if !response.isEmpty {
                llmInsight = response
            }
        }

        return formatFormalDiagnosticReport(profile: profile, llmSynthesis: llmInsight)
    }

    private func runLlamaInference(profile: DetailedFileProfile) async -> String {
        let systemPrompt = "You are Crucial Intelligence, an on-device macOS filesystem analyst. Provide a concise, technical risk summary of moving the specified asset to Trash, noting active process locks and rebuild steps. Avoid emojis."
        let userPrompt = """
        Asset: \(profile.name)
        Path: \(profile.path)
        Size: \(profile.formattedSize) (\(profile.exactBytes) bytes, \(profile.fileCount) entries)
        Classification: \(profile.fileClassification)
        Origin: \(profile.createdByApp) [\(profile.subsystemOrigin)]
        Purpose: \(profile.functionalPurpose)
        Dependency: \(profile.activeProcessDependency)
        Verdict: \(profile.deletionVerdict)
        Rebuild: \(profile.rebuildCommand ?? "None required")
        Risk: \(profile.vitalityRiskScore)/100 | Bloat: \(profile.bloatSeverityScore)/100
        """

        let prompt = "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\(systemPrompt)<|eot_id|><|start_header_id|>user<|end_header_id|>\n\(userPrompt)<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n"
        let output = await SubprocessRunner.run(executable: binPath, arguments: llamaArguments(prompt: prompt, maxTokens: 350))
        return extractAssistantOutput(from: output)
    }

    private func llamaArguments(prompt: String, maxTokens: Int) -> [String] {
        [
            "-m", modelPath,
            "-p", prompt,
            "-n", "\(maxTokens)",
            "-ngl", "99",
            "--temp", "0.2",
            "--top-k", "40",
            "-c", "2048",
            "--no-display-prompt",
            "--simple-io",
            "--single-turn",
            "--no-show-timings",
            "--log-disable"
        ]
    }

    private func extractAssistantOutput(from raw: String) -> String {
        var clean = raw
        if let range = raw.range(of: "<|start_header_id|>assistant<|end_header_id|>", options: .backwards) {
            clean = String(raw[range.upperBound...])
        } else if let marker = raw.range(of: "> ", options: .backwards) {
            clean = String(raw[marker.upperBound...])
        }
        return clean
            .replacing("Exiting...", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func formatFormalDiagnosticReport(profile: DetailedFileProfile, llmSynthesis: String? = nil) -> String {
        let rebuildBlock: String
        if let command = profile.rebuildCommand {
            rebuildBlock = "\n```bash\n\(command)\n```"
        } else {
            rebuildBlock = "None required (recreated automatically when needed)"
        }

        var report = """
        ### Telemetry Audit: \(profile.name)
        `\(profile.path)`

        **Identity & Provenance**
        - **Classification:** \(profile.fileClassification)
        - **Origin:** \(profile.createdByApp)
        - **Subsystem:** \(profile.subsystemOrigin)
        - **Footprint:** \(profile.formattedSize) (\(profile.exactBytes) bytes across \(profile.fileCount) entries)
        - **Modified:** \(profile.lastModified) (\(profile.daysIdle) days idle)

        **System Role**
        \(profile.functionalPurpose) \(profile.whyItExists)

        **Process & Dependency Check**
        - **Status:** \(profile.isProcessRunning ? "Active in running processes" : "Dormant / Inactive")
        - **Details:** \(profile.activeProcessDependency)

        **Safety Verdict: \(profile.deletionVerdict)**
        - **Immediate Impact:** \(profile.immediateImpact)
        - **After Removal:** \(profile.appRelaunchImpact)
        - **Rebuild Protocol:** \(rebuildBlock)

        **Diagnostic Indices**
        - **Vitality Risk:** \(profile.vitalityRiskScore) / 100
        - **Bloat Severity:** \(profile.bloatSeverityScore) / 100
        - **Recovery Cost:** \(profile.recoveryDifficultyScore) / 100
        """

        if let llm = llmSynthesis, !llm.isEmpty {
            report += "\n\n**Local Llama 3.2 Assessment**\n\(llm)"
        }
        return report
    }

    private func generateBuiltInTechnicalAnswer(for query: String) -> String {
        if query.localizedStandardContains("deriveddata") || query.localizedStandardContains("xcode") {
            return """
            **Xcode Intermediate Build Cache**

            Xcode stores module caches, compiled objects, and symbol indexes in `~/Library/Developer/Xcode/DerivedData/`.
            - **Safety:** Completely safe to move to Trash when active builds are closed.
            - **Recovery:** Xcode automatically rebuilds required targets on the next compile.
            """
        }

        if query.localizedStandardContains("node_modules") || query.localizedStandardContains("npm") {
            return """
            **Node.js Dependency Storage**

            `node_modules` directories contain local package dependencies per project.
            - **Safety:** Safe to remove on dormant projects without modifying source files or `package.json`.
            - **Recovery:** Run `npm install`, `pnpm install`, or `yarn` inside the repository folder.
            """
        }

        if query.localizedStandardContains("snapshot") || query.localizedStandardContains("time machine") || query.localizedStandardContains("system data") {
            return """
            **APFS Local Snapshots**

            macOS APFS captures local snapshots before updates and Time Machine syncs, which often appear under System Data.
            - **Inspect:** `tmutil listlocalsnapshots /`
            - **Maintenance:** Use the System Maintenance tab in Crucial to thin stale snapshots safely.
            """
        }

        return """
        **Crucial Storage Diagnostics**

        Crucial audits your APFS container across Xcode DerivedData, package dependency trees, browser caches, and orphaned app containers. All removals stage items safely to macOS Trash so everything remains recoverable.
        """
    }
}
