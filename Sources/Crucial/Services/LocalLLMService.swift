import Foundation

@MainActor
public final class LocalLLMService: ObservableObject {
    public static let shared = LocalLLMService()

    @Published public var isGenerating: Bool = false
    @Published public var isModelReady: Bool = false
    @Published public var modelDownloadPercent: Double = 0.0

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

    public func generateFreeformAnswer(for query: String) async -> String {
        checkModelStatus()
        guard isModelReady && FileManager.default.fileExists(atPath: binPath) else {
            return "Local LLM core is offline or initializing. Please verify model weights."
        }

        self.isGenerating = true
        let systemPrompt = "You are Crucial Diagnostic Core, an advanced macOS engineering terminal assistant. Provide direct, highly technical, concise, and structured answers regarding macOS systems, file storage, build caches, and system maintenance. Avoid boilerplate or cheerleading."
        let prompt = "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\(systemPrompt)<|eot_id|><|start_header_id|>user<|end_header_id|>\n\(query)<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n"

        let result = await executeLlamaProcess(prompt: prompt, maxTokens: 350)
        self.isGenerating = false
        return result.isEmpty ? "Diagnostic engine returned null telemetry." : result
    }

    private func runLlamaInference(profile: DetailedFileProfile) async -> String {
        let systemPrompt = """
        You are Crucial Diagnostic Core, a high-precision macOS filesystem analysis system. Provide an authoritative, technical risk assessment of deleting the specified asset. Explicitly comment on active process locks, rebuild feasibility, and performance trade-offs.
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
                    "-ngl", "99", // Offload all layers to Apple Silicon GPU
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
                process.standardError = Pipe() // Suppress stderr

                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()

                    if let rawOutput = String(data: data, encoding: .utf8) {
                        // Extract output after assistant header
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
        ### 📡 TELEMETRY AUDIT: \(profile.name)
        `CANONICAL: \(profile.path)`

        ---

        #### 1. IDENTITY & PROVENANCE
        - **Target Entity:** `\(profile.name)` (\(profile.isDirectory ? "Directory Hierarchy" : "Individual File"))
        - **Classification:** \(profile.fileClassification)
        - **Originating Application:** **\(profile.createdByApp)**
        - **Subsystem Domain:** `\(profile.subsystemOrigin)`
        - **Footprint:** **\(profile.formattedSize)** (\(profile.exactBytes) bytes across \(profile.fileCount) inodes)
        - **Telemetry Status:** Modified \(profile.lastModified) | \(profile.daysIdle) days idle

        #### 2. SYSTEM ROLE & RATIONALE (Why Does It Exist?)
        \(profile.functionalPurpose)

        *System Rationale:* \(profile.whyItExists)

        #### 3. RUNNING PROCESS & DEPENDENCY AUDIT
        - **Owning Process / Lock:** `\(profile.activeProcessDependency)`
        - **Execution State:** \(profile.isProcessRunning ? "⚠️ ACTIVE IN CURRENT SYSTEM PROCESS TABLE" : "✅ DORMANT / NO ACTIVE SYSTEM PROCESS")

        #### 4. DELETION DYNAMICS & RECOVERY PROTOCOL
        - **Safety Lock Status:** **\(profile.deletionVerdict)**
        - **Immediate Impact:** \(profile.immediateImpact)
        - **Relaunch Impact:** \(profile.appRelaunchImpact)
        - **Rebuild / Recovery Command:**
        \(rebuild)

        #### 5. HEALTH METRICS & RISK INDICES
        - **Vitality Risk Index:** `\(profile.vitalityRiskScore) / 100` *(Lower = Safer to purge)*
        - **Bloat Severity:** `\(profile.bloatSeverityScore) / 100` *(Higher = Priority waste)*
        - **Recovery Difficulty:** `\(profile.recoveryDifficultyScore) / 100`
        - **Safety Confidence:** `\(profile.safetyConfidencePercent)%`
        """

        if let llm = llmSynthesis, !llm.isEmpty {
            report += """


            ---

            #### 🧠 LOCAL LLAMA-3.2 (METAL) REASONING MEMO
            \(llm)
            """
        }

        return report
    }
}
