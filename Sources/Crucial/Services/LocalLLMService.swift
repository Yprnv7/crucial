import Foundation

@MainActor
public final class LocalLLMService: ObservableObject {
    public static let shared = LocalLLMService()

    @Published public var isGenerating: Bool = false
    @Published public var isModelReady: Bool = false
    @Published public var modelDownloadPercent: Double = 0.0

    // Multi-turn conversational memory buffer
    public struct ChatTurn: Sendable {
        public let role: String // "user" or "assistant"
        public let content: String
    }
    public var conversationHistory: [ChatTurn] = []

    public var binPath: String {
        let appBundleBin = Bundle.main.bundlePath + "/Contents/Resources/bin/llama-cli"
        if FileManager.default.isExecutableFile(atPath: appBundleBin) { return appBundleBin }
        let scratchBin = "/Users/py/.gemini/antigravity/scratch/crucial/bin/llama-b12633/llama-cli"
        if FileManager.default.isExecutableFile(atPath: scratchBin) { return scratchBin }
        return scratchBin
    }

    public var modelPath: String {
        let appBundleModel = Bundle.main.bundlePath + "/Contents/Resources/models/llama-3.2-1b-instruct-q4_k_m.gguf"
        if FileManager.default.fileExists(atPath: appBundleModel) { return appBundleModel }
        let scratchModel = "/Users/py/.gemini/antigravity/scratch/crucial/models/llama-3.2-1b-instruct-q4_k_m.gguf"
        if FileManager.default.fileExists(atPath: scratchModel) { return scratchModel }
        let homeModel = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Crucial/models/llama-3.2-1b-instruct-q4_k_m.gguf").path
        if FileManager.default.fileExists(atPath: homeModel) { return homeModel }
        return scratchModel
    }

    private init() {
        checkModelStatus()
    }

    public func clearConversationHistory() {
        conversationHistory.removeAll()
    }

    public func checkModelStatus() {
        let path = modelPath
        if FileManager.default.fileExists(atPath: path) {
            let attrs = try? FileManager.default.attributesOfItem(atPath: path)
            let size = (attrs?[.size] as? Int64) ?? 0
            if size > 700_000_000 { // > 700 MB
                self.isModelReady = true
                self.modelDownloadPercent = 100.0
                return
            }
        }
        self.isModelReady = false
    }

    // MARK: - Streaming Freeform Answer with Multi-Turn Context
    public func streamFreeformAnswer(for query: String, onToken: @escaping @MainActor (String) -> Void) async -> String {
        checkModelStatus()
        guard isModelReady && FileManager.default.fileExists(atPath: binPath) else {
            let fallback = "Local Llama 3.2 engine is initializing. Please verify model weights."
            onToken(fallback)
            return fallback
        }

        self.isGenerating = true
        let systemPrompt = "You are Crucial Intelligence, an advanced on-device macOS storage systems engineer. Provide direct, highly technical, clear, and structured answers regarding macOS systems, APFS, build caches, and storage maintenance. Avoid fluff."

        // Build multi-turn prompt in Llama 3.2 format
        var prompt = "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\(systemPrompt)<|eot_id|>"
        for turn in conversationHistory.suffix(4) { // Maintain last 4 turns for context
            prompt += "<|start_header_id|>\(turn.role)<|end_header_id|>\n\(turn.content)<|eot_id|>"
        }
        prompt += "<|start_header_id|>user<|end_header_id|>\n\(query)<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n"

        let generated = await executeLlamaStreaming(prompt: prompt, maxTokens: 400, onToken: onToken)
        self.isGenerating = false

        // Record in conversation history
        conversationHistory.append(ChatTurn(role: "user", content: query))
        conversationHistory.append(ChatTurn(role: "assistant", content: generated))

        return generated
    }

    // MARK: - Deep Item Explanation
    public func generateDeepExplanation(for item: FileItem) async -> String {
        let profile = FileDiagnosticEngine.shared.profile(item: item)
        checkModelStatus()

        var llmInsight: String? = nil
        if isModelReady && FileManager.default.fileExists(atPath: binPath) {
            self.isGenerating = true
            let response = await runLlamaInference(profile: profile)
            self.isGenerating = false
            if !response.isEmpty {
                llmInsight = response
            }
        }

        return formatFormalDiagnosticReport(profile: profile, llmSynthesis: llmInsight)
    }

    private func runLlamaInference(profile: DetailedFileProfile) async -> String {
        let systemPrompt = """
        You are Crucial Intelligence, an advanced macOS filesystem analysis system. Provide an authoritative, technical risk assessment of deleting the specified asset. Explicitly comment on active process locks, rebuild feasibility, and performance trade-offs.
        """

        let userPrompt = """
        Asset: \(profile.name)
        Path: \(profile.path)
        Size: \(profile.formattedSize) (\(profile.exactBytes) bytes, \(profile.fileCount) inodes)
        Classification: \(profile.fileClassification)
        Origin: \(profile.createdByApp) [\(profile.subsystemOrigin)]
        Functional Role: \(profile.functionalPurpose)
        Reason for Existence: \(profile.whyItExists)
        Process Dependency: \(profile.activeProcessDependency) (Active Running: \(profile.isProcessRunning))
        Deletion Feasibility: \(profile.deletionVerdict)
        Immediate Consequence: \(profile.immediateImpact)
        Relaunch Consequence: \(profile.appRelaunchImpact)
        Rebuild: \(profile.rebuildCommand ?? "N/A")
        Vitality Risk: \(profile.vitalityRiskScore)/100 | Bloat: \(profile.bloatSeverityScore)/100 | Recovery Difficulty: \(profile.recoveryDifficultyScore)/100

        Provide an executive technical summary and operational recommendation.
        """

        let prompt = "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\(systemPrompt)<|eot_id|><|start_header_id|>user<|end_header_id|>\n\(userPrompt)<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n"

        return await executeLlamaProcess(prompt: prompt, maxTokens: 380)
    }

    private func executeLlamaStreaming(prompt: String, maxTokens: Int, onToken: @escaping @MainActor (String) -> Void) async -> String {
        let binary = self.binPath
        let model = self.modelPath

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: binary)
                process.arguments = [
                    "-m", model,
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

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()

                var accumulated = ""
                var hasPassedHeader = false

                pipe.fileHandleForReading.readabilityHandler = { fileHandle in
                    let data = fileHandle.availableData
                    guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }

                    accumulated += text

                    if !hasPassedHeader {
                        if let range = accumulated.range(of: "<|start_header_id|>assistant<|end_header_id|>", options: .backwards) {
                            hasPassedHeader = true
                            let tokens = String(accumulated[range.upperBound...])
                            DispatchQueue.main.async {
                                onToken(tokens)
                            }
                        } else if let marker = accumulated.range(of: "> ", options: .backwards) {
                            hasPassedHeader = true
                            let tokens = String(accumulated[marker.upperBound...])
                            DispatchQueue.main.async {
                                onToken(tokens)
                            }
                        }
                    } else {
                        // Stream ongoing tokens directly
                        let cleanText = text.replacingOccurrences(of: "Exiting...", with: "")
                        DispatchQueue.main.async {
                            onToken(cleanText)
                        }
                    }
                }

                do {
                    try process.run()
                    process.waitUntilExit()
                    pipe.fileHandleForReading.readabilityHandler = nil

                    var cleanText = accumulated
                    if let range = cleanText.range(of: "<|start_header_id|>assistant<|end_header_id|>", options: .backwards) {
                        cleanText = String(cleanText[range.upperBound...])
                    } else if let marker = cleanText.range(of: "> ", options: .backwards) {
                        cleanText = String(cleanText[marker.upperBound...])
                    }
                    cleanText = cleanText.replacingOccurrences(of: "Exiting...", with: "").trimmingCharacters(in: .whitespacesAndNewlines)

                    continuation.resume(returning: cleanText.isEmpty ? "Diagnostics synthesis completed." : cleanText)
                } catch {
                    continuation.resume(returning: "Error executing on-device Llama 3.2 inference.")
                }
            }
        }
    }

    private func executeLlamaProcess(prompt: String, maxTokens: Int) async -> String {
        let binary = self.binPath
        let model = self.modelPath

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: binary)
                process.arguments = [
                    "-m", model,
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

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()

                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()

                    if let rawOutput = String(data: data, encoding: .utf8) {
                        var cleanText = rawOutput
                        if let range = rawOutput.range(of: "<|start_header_id|>assistant<|end_header_id|>", options: .backwards) {
                            cleanText = String(rawOutput[range.upperBound...])
                        } else if let marker = rawOutput.range(of: "> ", options: .backwards) {
                            cleanText = String(rawOutput[marker.upperBound...])
                        }

                        cleanText = cleanText.replacingOccurrences(of: "Exiting...", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if !cleanText.isEmpty {
                            continuation.resume(returning: cleanText)
                            return
                        }
                    }
                } catch {
                    // Fall back
                }
                continuation.resume(returning: "")
            }
        }
    }

    public func formatFormalDiagnosticReport(profile: DetailedFileProfile, llmSynthesis: String? = nil) -> String {
        let rebuild = profile.rebuildCommand != nil ? "\n```bash\n\(profile.rebuildCommand!)\n```" : "*None required (recreated automatically on demand)*"

        var report = """
        ### 📡 Telemetry Audit: \(profile.name)
        `Canonical: \(profile.path)`

        ---

        #### 1. Identity & Provenance
        - **Target Entity:** `\(profile.name)` (\(profile.isDirectory ? "Directory Hierarchy" : "Individual File"))
        - **Classification:** \(profile.fileClassification)
        - **Originating Application:** **\(profile.createdByApp)**
        - **Subsystem Domain:** `\(profile.subsystemOrigin)`
        - **Footprint:** **\(profile.formattedSize)** (\(profile.exactBytes) bytes across \(profile.fileCount) inodes)
        - **Telemetry Status:** Modified \(profile.lastModified) · \(profile.daysIdle) days idle

        #### 2. System Role & Rationale
        \(profile.functionalPurpose)

        *System Rationale:* \(profile.whyItExists)

        #### 3. Running Process & Dependency Audit
        - **Owning Process / Lock:** `\(profile.activeProcessDependency)`
        - **Execution State:** \(profile.isProcessRunning ? "⚠️ Active in Process Table" : "✅ Dormant / No Active Process")

        #### 4. Deletion Dynamics & Recovery Protocol
        - **Safety Lock Status:** **\(profile.deletionVerdict)**
        - **Immediate Impact:** \(profile.immediateImpact)
        - **Relaunch Impact:** \(profile.appRelaunchImpact)
        - **Rebuild Command:**
        \(rebuild)

        #### 5. Health Metrics & Risk Indices
        - **Vitality Risk Index:** `\(profile.vitalityRiskScore) / 100` *(Lower = Safer to purge)*
        - **Bloat Severity:** `\(profile.bloatSeverityScore) / 100` *(Higher = Priority waste)*
        - **Recovery Difficulty:** `\(profile.recoveryDifficultyScore) / 100`
        - **Safety Confidence:** `\(profile.safetyConfidencePercent)%`
        """

        if let llm = llmSynthesis, !llm.isEmpty {
            report += """


            ---

            #### 🧠 Local Llama 3.2 (Metal) Reasoning Memo
            \(llm)
            """
        }

        return report
    }
}
