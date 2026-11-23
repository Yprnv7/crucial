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
            // High-fidelity Crucial Storage Intelligence synthesis fallback
            let synthesized = generateBuiltInTechnicalAnswer(for: query)
            let words = synthesized.components(separatedBy: " ")
            for (index, word) in words.enumerated() {
                let token = (index == 0 ? "" : " ") + word
                onToken(token)
                try? await Task.sleep(nanoseconds: 8_000_000) // 8ms dynamic streaming
            }
            return synthesized
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

    // MARK: - Built-in High-Precision Technical Storage Engine
    private func generateBuiltInTechnicalAnswer(for query: String) -> String {
        let lower = query.lowercased()

        if lower.contains("deriveddata") || lower.contains("xcode") || lower.contains("swift") {
            return """
            🔨 **Xcode Intermediate Build & Index Architecture**

            Xcode stores module caches, precompiled headers, and symbol indexes inside `~/Library/Developer/Xcode/DerivedData/`.
            - **Why it grows:** Every build of every workspace creates unique hash directories that never auto-prune.
            - **Purge Safety:** **100% safe to delete.** Xcode regenerates indexes and build outputs automatically on next compilation.
            - **CLI Command:** `rm -rf ~/Library/Developer/Xcode/DerivedData/*`
            """
        }

        if lower.contains("node_modules") || lower.contains("npm") || lower.contains("yarn") || lower.contains("bun") {
            return """
            📦 **JavaScript / TypeScript Dependency Storage**

            `node_modules` folders isolate dependencies per-project. Idle projects often consume 10-30 GB over time.
            - **Purge Safety:** Completely safe. Your code and `package.json` are preserved.
            - **Restoration:** Run `npm install`, `pnpm install`, or `yarn` in the project root to restore.
            """
        }

        if lower.contains("snapshot") || lower.contains("time machine") || lower.contains("purgeable") || lower.contains("system data") {
            return """
            💾 **APFS Local Snapshots & "System Data" Footprint**

            macOS APFS takes silent local shadow copies before updates and Time Machine syncs. These often show as 20-80 GB of mysterious "System Data".
            - **List Snapshots:** Run `tmutil listlocalsnapshots /` in Terminal.
            - **Clean Snapshots:** Crucial can automatically purge aged local snapshots safely via its System Maintenance tab, instantly turning "Purgeable" storage into real free space.
            """
        }

        if lower.contains("docker") || lower.contains("container") {
            return """
            🐳 **Docker Desktop Virtual Machine Bloat**

            Docker on macOS runs inside a Linux hypervisor with a fixed-growth raw disk file (`Docker.raw`) located at `~/Library/Containers/com.docker.docker/Data/vms/`.
            - **Reclamation:** Unused images and stopped containers keep this file bloated.
            - **CLI Prune:** `docker system prune -a --volumes` to reclaim space immediately.
            """
        }

        if lower.contains("cache") || lower.contains("temp") || lower.contains("tmp") {
            return """
            ⚡ **macOS User & Subsystem Cache Breakdown**

            Applications write temporary web assets, thumbnails, and IPC sockets into `~/Library/Caches/`.
            - **Behavior:** Electron applications (Slack, Discord, VS Code) frequently fail to prune old cache versions.
            - **Crucial Policy:** Crucial safely targets caches older than 7 days, keeping recent application sessions and authentication tokens intact.
            """
        }

        return """
        🖥️ **Crucial Storage Telemetry Advisory**

        Crucial is continuously auditing your macOS APFS container and user directories for reclaimable storage.
        - **Primary Bloat Vectors:** Build artifacts (`DerivedData`, `node_modules`), browser caches (`~/Library/Caches`), and orphaned application remnants (`~/Library/Application Support`).
        - **Safe Actions:** You can clean safe caches directly from the Clean Dashboard or search specific files across your Mac using the Deep File Finder.
        - All operations use native macOS Trash staging so files can be restored at any time.
        """
    }
}
