import Foundation
import Observation

@Observable
@MainActor
public final class CrucialChatService {
    public static let shared = CrucialChatService()

    public var messages: [ChatMessage] = []
    public var isTyping: Bool = false

    private init() {
        loadWelcomeMessage()
    }

    public func loadWelcomeMessage() {
        LocalLLMService.shared.clearConversationHistory()
        if messages.isEmpty {
            let welcome = ChatMessage(
                sender: .assistant,
                text: """
                **Crucial Diagnostic Console**
                On-device storage analysis and file provenance engine active.

                Select any scanned item or ask a system question below.
                """,
                timestamp: .now
            )
            messages.append(welcome)
        }
    }

    public func sendUserMessage(_ text: String, contextItem: FileItem? = nil) {
        let userMsg = ChatMessage(
            sender: .user,
            text: text,
            timestamp: .now,
            contextItem: contextItem
        )
        messages.append(userMsg)

        isTyping = true
        Task {
            await generateResponse(to: text, contextItem: contextItem)
            isTyping = false
        }
    }

    public func askAbout(item: FileItem) {
        sendUserMessage("Diagnose asset: \(item.path)", contextItem: item)
    }

    private func generateResponse(to query: String, contextItem: FileItem?) async {
        let lower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner = FileScannerService.shared

        if let item = contextItem {
            await respondAboutItem(item)
            return
        }

        let fileSearchKeywords = extractFileSearchKeywords(from: lower)
        if !fileSearchKeywords.isEmpty {
            let found = await SystemFileSearchService.shared.findFiles(matchingKeywords: fileSearchKeywords, maxResults: 150)
            if let firstFile = found.first {
                let home = URL.homeDirectory.path
                let userFiles = found.filter { $0.path.hasPrefix(home) }
                let systemFiles = found.filter { !$0.path.hasPrefix(home) }

                var text = "**Found \(found.count) matching item\(found.count == 1 ? "" : "s")**\n"

                if !userFiles.isEmpty {
                    text += "\n**User Directory Files (\(userFiles.count))**\n"
                    for file in userFiles.prefix(20) {
                        text += "- **\(file.name)** (\(file.formattedSize)) · `\(file.displayPath)`\n"
                    }
                }

                if !systemFiles.isEmpty {
                    text += "\n**macOS System & Library Files (\(systemFiles.count))**\n"
                    for file in systemFiles.prefix(10) {
                        text += "- `\(file.path)` (\(file.formattedSize))\n"
                    }
                }

                text += userFiles.isEmpty
                    ? "\nSystem files remain protected under macOS System Integrity Protection."
                    : "\nUser files are marked protected to prevent accidental removal."

                messages.append(ChatMessage(
                    sender: .assistant,
                    text: text,
                    matchedFiles: found,
                    suggestedAction: .revealInFinder(path: firstFile.path)
                ))
                return
            }
        }

        if lower.contains("clean safe") || lower == "clean" || lower.contains("clean all safe") || lower.contains("free up space") {
            let total = scanner.totalCleanableBytes
            if total > 0 {
                let formatted = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
                let text = """
                **Ready to Clean Safe Items**

                Crucial identified **\(formatted)** of safe, disposable files across Xcode DerivedData, browser caches, and idle build folders. Removals always stage to macOS Trash cleanly.
                """
                messages.append(ChatMessage(sender: .assistant, text: text, suggestedAction: .cleanAllSafe(size: total)))
            } else {
                messages.append(ChatMessage(
                    sender: .assistant,
                    text: "No disposable build caches or safe cleanup targets are currently detected. Run a rescan after your next build.",
                    suggestedAction: .rescan
                ))
            }
            return
        }

        if lower.contains("disk full") || lower.contains("storage") || lower.contains("taking up space") || lower.contains("space") {
            let usedGB = (Double(scanner.hardwareInfo.usedBytes) / 1_073_741_824).formatted(.number.precision(.fractionLength(1)))
            let freeGB = (Double(scanner.diskFreeBytes) / 1_073_741_824).formatted(.number.precision(.fractionLength(1)))
            let cleanable = ByteCountFormatter.string(fromByteCount: scanner.totalCleanableBytes, countStyle: .file)

            var catBreakdown = ""
            for cat in JunkCategory.allCases where cat != .custom {
                let items = scanner.itemsByCategory[cat] ?? []
                let size = items.reduce(0) { $0 + $1.size }
                if size > 0 {
                    catBreakdown += "\n- **\(cat.rawValue)**: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) (\(items.count) items)"
                }
            }

            let text = """
            **Storage Health Overview**

            - **Used Storage:** \(usedGB) GB (\(Int(scanner.usedDiskPercent * 100))%)
            - **Available Space:** \(freeGB) GB free
            - **Cleanable Targets:** \(cleanable)
            \(catBreakdown.isEmpty ? "\nNo major junk categories detected." : "\n**Cleanable Breakdown:**\(catBreakdown)")
            """

            let action: ChatAction? = scanner.totalCleanableBytes > 0 ? .cleanAllSafe(size: scanner.totalCleanableBytes) : nil
            messages.append(ChatMessage(sender: .assistant, text: text, suggestedAction: action))
            return
        }

        if lower.contains("deriveddata") || lower.contains("xcode") {
            let devItems = scanner.itemsByCategory[.devArtifacts] ?? []
            let derivedSize = devItems.filter { $0.path.contains("DerivedData") }.reduce(0) { $0 + $1.size }
            let formatted = ByteCountFormatter.string(fromByteCount: derivedSize, countStyle: .file)
            let text = """
            **Xcode DerivedData**

            `DerivedData` caches intermediate compiled objects and SourceKit symbol indexes.
            - **Current Footprint:** \(formatted)
            - **Safety:** 100% safe to move to Trash when active builds are idle. Xcode regenerates required modules on the next compile.
            """
            let action: ChatAction? = derivedSize > 0 ? .cleanCategory(.devArtifacts, size: derivedSize) : nil
            messages.append(ChatMessage(sender: .assistant, text: text, suggestedAction: action))
            return
        }

        if lower.contains("node_modules") || lower.contains("npm") || lower.contains("yarn") {
            let devItems = scanner.itemsByCategory[.devArtifacts] ?? []
            let nodeSize = devItems.filter { $0.name.contains("node_modules") }.reduce(0) { $0 + $1.size }
            let formatted = ByteCountFormatter.string(fromByteCount: nodeSize, countStyle: .file)
            let text = """
            **Node.js Dependencies (`node_modules`)**

            Stores local package dependencies per repository. Source code and `package.json` remain untouched.
            - **Current Footprint:** \(formatted)
            - **Restore:** Run `npm install` or `pnpm install` in the project directory when resuming work.
            """
            let action: ChatAction? = nodeSize > 0 ? .cleanCategory(.devArtifacts, size: nodeSize) : nil
            messages.append(ChatMessage(sender: .assistant, text: text, suggestedAction: action))
            return
        }

        if lower.contains("cache") || lower.contains("library/caches") {
            let cacheItems = scanner.itemsByCategory[.systemCache] ?? []
            let cacheSize = cacheItems.reduce(0) { $0 + $1.size }
            let formatted = ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file)
            let text = """
            **Application Caches (`~/Library/Caches`)**

            Caches store temporary thumbnails, web assets, and downloads for browsers and desktop apps.
            - **Current Footprint:** \(formatted)
            - **Safety:** Safe to stage to Trash. Credentials and user data are not stored in `~/Library/Caches`.
            """
            let action: ChatAction? = cacheSize > 0 ? .cleanCategory(.systemCache, size: cacheSize) : nil
            messages.append(ChatMessage(sender: .assistant, text: text, suggestedAction: action))
            return
        }

        if lower.contains("safe") || lower.contains("break") || lower.contains("vital") || lower.contains("risk") {
            let text = """
            **Crucial Safety Model**

            1. **Vitality Protection:** System directories (`/System`, `/usr`), `.git` repositories, and personal source code are locked against accidental deletion.
            2. **macOS Trash Staging:** Crucial never executes irreversible `rm -rf` commands. Every removal uses Finder/FileManager Trash APIs so files stay recoverable.
            3. **Symlink Guard:** Symbolic links resolving outside safe user folders are automatically verified before staging.
            """
            messages.append(ChatMessage(sender: .assistant, text: text))
            return
        }

        let replyId = UUID()
        messages.append(ChatMessage(id: replyId, sender: .assistant, text: ""))

        _ = await LocalLLMService.shared.streamFreeformAnswer(for: query) { token in
            if let idx = self.messages.firstIndex(where: { $0.id == replyId }) {
                self.messages[idx].text += token
            }
        }
    }

    private func respondAboutItem(_ item: FileItem) async {
        let text = await LocalLLMService.shared.generateDeepExplanation(for: item)
        let action: ChatAction? = item.assessment.level != .vital ? .trashItem(url: item.url, name: item.name, size: item.size) : nil
        messages.append(ChatMessage(sender: .assistant, text: text, contextItem: item, suggestedAction: action))
    }

    public func executeAction(_ action: ChatAction, for messageId: UUID) {
        if let idx = messages.firstIndex(where: { $0.id == messageId }) {
            messages[idx].isActionExecuted = true
        }

        let scanner = FileScannerService.shared

        switch action {
        case .cleanAllSafe(let size):
            let result = scanner.cleanSelected()
            let formatted = ByteCountFormatter.string(fromByteCount: result.bytesFreed > 0 ? result.bytesFreed : size, countStyle: .file)
            messages.append(ChatMessage(
                sender: .assistant,
                text: "Moved \(result.succeeded) items (\(formatted)) safely to macOS Trash."
            ))

        case .cleanCategory(let cat, let size):
            let result = scanner.cleanSelected(in: cat)
            let formatted = ByteCountFormatter.string(fromByteCount: result.bytesFreed > 0 ? result.bytesFreed : size, countStyle: .file)
            messages.append(ChatMessage(
                sender: .assistant,
                text: "Cleaned \(cat.rawValue): moved \(result.succeeded) items (\(formatted)) to macOS Trash."
            ))

        case .trashItem(let url, let name, let size):
            do {
                let dummyAssessment = VitalityEngine.shared.assess(url: url, size: size)
                let file = FileItem(url: url, name: name, size: size, isDirectory: false, assessment: dummyAssessment)
                try SafetyTrashService.shared.trash(item: file)
                for cat in scanner.itemsByCategory.keys {
                    scanner.itemsByCategory[cat]?.removeAll { $0.url == url }
                }
                scanner.recalculateCleanableBytes()
                scanner.refreshDiskSpace()
                let formatted = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
                messages.append(ChatMessage(sender: .assistant, text: "Moved '\(name)' (\(formatted)) to macOS Trash."))
            } catch {
                messages.append(ChatMessage(sender: .assistant, text: "Action blocked: \(error.localizedDescription)"))
            }

        case .navigateCategory(let cat):
            NavigationStore.shared.openCategory(cat)

        case .revealInFinder(let path):
            FinderOpener.reveal(path: path)

        case .inspectInFileFinder(let name):
            NavigationStore.shared.activeSearchQuery = name
            NavigationStore.shared.navigate(to: .fileFinder)

        case .rescan:
            Task {
                await scanner.scanQuickCleanDashboard()
                let cleanable = ByteCountFormatter.string(fromByteCount: scanner.totalCleanableBytes, countStyle: .file)
                messages.append(ChatMessage(sender: .assistant, text: "Scan finished: \(cleanable) identified."))
            }
        }
    }

    private func extractFileSearchKeywords(from lower: String) -> [String] {
        if lower.contains("cv") || lower.contains("resume") || lower.contains("curriculum vitae") {
            return ["cv", "resume"]
        }

        let searchPrefixes = [
            "show all files with ", "show files with ", "files with ", "show all ",
            "where is ", "where are ", "where's ", "find ", "locate ", "search for ", "search ", "show me "
        ]
        for prefix in searchPrefixes {
            if let range = lower.range(of: prefix) {
                var term = String(lower[range.upperBound...])
                    .replacing("in name", with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: " ?!.,;\"'"))
                let stopwords = ["my ", "the ", "files", "file", "all ", "any "]
                for sw in stopwords {
                    if term.hasPrefix(sw) {
                        term = String(term.dropFirst(sw.count)).trimmingCharacters(in: .whitespaces)
                    }
                    let suffixWord = " " + sw.trimmingCharacters(in: .whitespaces)
                    if term.hasSuffix(suffixWord) {
                        term = String(term.dropLast(suffixWord.count)).trimmingCharacters(in: .whitespaces)
                    }
                }
                term = term.trimmingCharacters(in: .whitespacesAndNewlines)
                if term.count >= 2 { return [term] }
            }
        }

        if lower.contains("where") {
            let terms = lower
                .replacing("where", with: "")
                .replacing("files", with: "")
                .replacing("file", with: "")
                .replacing("are", with: "")
                .replacing("is", with: "")
                .replacing("my", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: " ?!.,;\"'"))
            if terms.count >= 2 { return [terms] }
        }

        return []
    }
}
