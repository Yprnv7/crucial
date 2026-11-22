import Foundation
import SwiftUI

@MainActor
public final class CrucialChatService: ObservableObject {
    public static let shared = CrucialChatService()

    @Published public var messages: [ChatMessage] = []
    @Published public var isTyping: Bool = false

    private init() {
        loadWelcomeMessage()
    }

    public func loadWelcomeMessage() {
        LocalLLMService.shared.clearConversationHistory()
        if messages.isEmpty {
            let welcome = ChatMessage(
                sender: .assistant,
                text: """
                **Crucial Diagnostic Interface · v1.0**
                `System: macOS Darwin · Subsystem Auditor Active`

                Awaiting query or target inspection. Select any file in your storage breakdown or submit a system inquiry below.
                """,
                timestamp: Date()
            )
            messages.append(welcome)
        }
    }

    public func sendUserMessage(_ text: String, contextItem: FileItem? = nil) {
        let userMsg = ChatMessage(
            sender: .user,
            text: text,
            timestamp: Date(),
            contextItem: contextItem
        )
        messages.append(userMsg)

        // Process response
        isTyping = true
        Task {
            await self.generateResponse(to: text, contextItem: contextItem)
            await MainActor.run {
                self.isTyping = false
            }
        }
    }

    public func askAbout(item: FileItem) {
        let prompt = "DIAGNOSE_ASSET: \(item.path)"
        sendUserMessage(prompt, contextItem: item)
    }

    private func generateResponse(to query: String, contextItem: FileItem?) async {
        let lower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner = FileScannerService.shared

        // 1. If inquiring about a specific file or context item
        if let item = contextItem {
            await respondAboutItem(item)
            return
        }

        // 2. Action Request: Clean Safe Files
        if lower.contains("clean safe") || lower == "clean" || lower.contains("clean all safe") || lower.contains("free up space") {
            let total = scanner.totalCleanableBytes
            if total > 0 {
                let formatted = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
                let text = """
                🧹 **Ready to Clean Safe Files**
                
                Crucial has identified **\(formatted)** of completely safe, disposable items:
                - Xcode DerivedData build caches
                - Browser & temporary application caches
                - Project build folders (`node_modules`, `.venv`)
                
                Deleting these files will **not** affect your source code, applications, or personal files. Deletions are moved to your macOS Trash.
                
                Would you like me to move these to Trash now?
                """
                let reply = ChatMessage(
                    sender: .assistant,
                    text: text,
                    suggestedAction: .cleanAllSafe(size: total)
                )
                messages.append(reply)
            } else {
                let reply = ChatMessage(
                    sender: .assistant,
                    text: "✨ Your Mac is in top shape! There are currently 0 cleanable safe junk files detected. Run a quick rescan if you recently used Xcode or compiled code.",
                    suggestedAction: .rescan
                )
                messages.append(reply)
            }
            return
        }

        // 3. Question: Why is my disk full?
        if lower.contains("disk full") || lower.contains("storage") || lower.contains("taking up space") || lower.contains("space") {
            let usedGB = String(format: "%.1f GB", Double(scanner.diskTotalBytes - scanner.diskFreeBytes) / (1024*1024*1024))
            let freeGB = String(format: "%.1f GB", Double(scanner.diskFreeBytes) / (1024*1024*1024))
            let cleanable = ByteCountFormatter.string(fromByteCount: scanner.totalCleanableBytes, countStyle: .file)

            var catBreakdown = ""
            for cat in JunkCategory.allCases where cat != .custom {
                let items = scanner.itemsByCategory[cat] ?? []
                let size = items.reduce(0) { $0 + $1.size }
                if size > 0 {
                    catBreakdown += "\n- **\(cat.rawValue)**: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) (\(items.count) files)"
                }
            }

            let text = """
            📊 **Mac Storage Health Overview**
            
            - **Used Storage:** \(usedGB) (\(Int(scanner.usedDiskPercent * 100))% used)
            - **Available Storage:** \(freeGB) free
            - **Immediately Cleanable Junk:** **\(cleanable)**
            
            **Where is space being consumed?**\(catBreakdown.isEmpty ? "\nNo major junk detected yet." : catBreakdown)
            
            Developer build artifacts and browser caches typically accumulate the fastest on macOS because apps never auto-prune them.
            """

            let action: ChatAction? = scanner.totalCleanableBytes > 0 ? .cleanAllSafe(size: scanner.totalCleanableBytes) : nil
            let reply = ChatMessage(
                sender: .assistant,
                text: text,
                suggestedAction: action
            )
            messages.append(reply)
            return
        }

        // 4. Question: Xcode DerivedData
        if lower.contains("deriveddata") || lower.contains("xcode") {
            let devItems = scanner.itemsByCategory[.devArtifacts] ?? []
            let derivedSize = devItems.filter { $0.path.contains("DerivedData") }.reduce(0) { $0 + $1.size }
            let formatted = ByteCountFormatter.string(fromByteCount: derivedSize, countStyle: .file)

            let text = """
            🔨 **What is Xcode DerivedData?**
            
            `DerivedData` is where Xcode stores intermediate build products, module caches, and index files for every Swift/Objective-C project you build.
            
            - **Current DerivedData Size:** **\(formatted)**
            - **Is it safe to delete?** **Yes, 100% safe.** Deleting DerivedData is standard practice for iOS/Mac developers. It resolves indexing bugs, compiler cache corruption, and frees gigabytes instantly.
            - **What happens after deletion?** Xcode simply re-indexes and rebuilds your target binaries on your next build. Your source code is untouched.
            """
            let action: ChatAction? = derivedSize > 0 ? .cleanCategory(.devArtifacts, size: derivedSize) : nil
            let reply = ChatMessage(
                sender: .assistant,
                text: text,
                suggestedAction: action
            )
            messages.append(reply)
            return
        }

        // 5. Question: node_modules
        if lower.contains("node_modules") || lower.contains("npm") || lower.contains("yarn") {
            let devItems = scanner.itemsByCategory[.devArtifacts] ?? []
            let nodeSize = devItems.filter { $0.name.contains("node_modules") }.reduce(0) { $0 + $1.size }
            let formatted = ByteCountFormatter.string(fromByteCount: nodeSize, countStyle: .file)

            let text = """
            📦 **What are node_modules?**
            
            `node_modules` folders contain installed third-party JavaScript/TypeScript dependency packages. Because each project downloads its own dependencies, idle repositories from months ago quietly hoard tens of gigabytes.
            
            - **Current node_modules Size:** **\(formatted)**
            - **Is it safe to delete?** **Yes, completely safe.** Your project source code and `package.json` are untouched.
            - **How to restore:** Whenever you need to work on the project again, just open its folder and run:
              ```bash
              npm install  # or yarn / pnpm install
              ```
            """
            let action: ChatAction? = nodeSize > 0 ? .cleanCategory(.devArtifacts, size: nodeSize) : nil
            let reply = ChatMessage(
                sender: .assistant,
                text: text,
                suggestedAction: action
            )
            messages.append(reply)
            return
        }

        // 6. Question: System & User Caches (~/Library/Caches)
        if lower.contains("cache") || lower.contains("library/caches") {
            let cacheItems = scanner.itemsByCategory[.systemCache] ?? []
            let cacheSize = cacheItems.reduce(0) { $0 + $1.size }
            let formatted = ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file)

            let text = """
            ⚡ **What is stored in ~/Library/Caches?**
            
            This directory stores local data for web browsers (Google Chrome, Safari), Electron apps (Slack, Discord, VS Code, Spotify), and macOS services to load pages faster.
            
            - **Current Cleanable Cache Size:** **\(formatted)**
            - **Is it safe to delete?** **Yes.** Crucial only targets stale and oversized cache stores.
            - **Impact:** Websites or apps may take a couple of extra seconds to load on their first launch as fresh caches are created. No user accounts, history, or passwords are deleted.
            """
            let action: ChatAction? = cacheSize > 0 ? .cleanCategory(.systemCache, size: cacheSize) : nil
            let reply = ChatMessage(
                sender: .assistant,
                text: text,
                suggestedAction: action
            )
            messages.append(reply)
            return
        }

        // 7. Question: Orphaned App Residue
        if lower.contains("orphan") || lower.contains("residue") || lower.contains("uninstalled") {
            let appItems = scanner.itemsByCategory[.appResidue] ?? []
            let appSize = appItems.reduce(0) { $0 + $1.size }
            let formatted = ByteCountFormatter.string(fromByteCount: appSize, countStyle: .file)

            let text = """
            🗑️ **What is Orphaned App Residue?**
            
            When you drag an application to the macOS Trash, macOS only deletes the `.app` bundle. It leaves behind its config, databases, and logs in `~/Library/Application Support/`.
            
            Crucial inspects your `/Applications` folder and flags directories that belong to apps you already uninstalled.
            
            - **Current Orphaned Residue:** **\(formatted)** (\(appItems.count) uninstalled app folders)
            - **Is it safe to delete?** **Yes.** Since the parent application is no longer on your Mac, these leftover files serve no purpose.
            """
            let action: ChatAction? = appSize > 0 ? .cleanCategory(.appResidue, size: appSize) : nil
            let reply = ChatMessage(
                sender: .assistant,
                text: text,
                suggestedAction: action
            )
            messages.append(reply)
            return
        }

        // 8. Question: Safety / Will it break my Mac?
        if lower.contains("safe") || lower.contains("break") || lower.contains("vital") || lower.contains("risk") {
            let text = """
            🛡️ **Crucial Zero-Risk Safety Architecture**
            
            Crucial is engineered so you **cannot accidentally break your Mac**:
            1. **Vitality Score (0 to 100):** Every file is evaluated against system protection paths (SIP), macOS System files, and active code repositories. Anything vital is locked from deletion.
            2. **Trash Staging (No `rm -rf`):** Deletions always use `FileManager.default.trashItem`. Files sit safely in your macOS Trash so you can restore them anytime.
            3. **Explanation Before Action:** Crucial always explains what a folder is first before executing any cleanup.
            """
            let reply = ChatMessage(
                sender: .assistant,
                text: text
            )
            messages.append(reply)
            return
        }

        // Streaming Real-Time Local LLM Response
        let replyId = UUID()
        let placeholder = ChatMessage(
            id: replyId,
            sender: .assistant,
            text: ""
        )
        messages.append(placeholder)

        _ = await LocalLLMService.shared.streamFreeformAnswer(for: query) { token in
            if let idx = self.messages.firstIndex(where: { $0.id == replyId }) {
                self.messages[idx].text += token
            }
        }
    }

    private func respondAboutItem(_ item: FileItem) async {
        let text = await LocalLLMService.shared.generateDeepExplanation(for: item)

        let action: ChatAction?
        if item.assessment.level != .vital {
            action = .trashItem(url: item.url, name: item.name, size: item.size)
        } else {
            action = nil
        }

        let reply = ChatMessage(
            sender: .assistant,
            text: text,
            contextItem: item,
            suggestedAction: action
        )
        messages.append(reply)
    }

    public func executeAction(_ action: ChatAction, for messageId: UUID) {
        // Mark action executed
        if let idx = messages.firstIndex(where: { $0.id == messageId }) {
            messages[idx].isActionExecuted = true
        }

        let scanner = FileScannerService.shared

        switch action {
        case .cleanAllSafe(let size):
            let result = scanner.cleanSelected()
            let formatted = ByteCountFormatter.string(fromByteCount: result.bytesFreed > 0 ? result.bytesFreed : size, countStyle: .file)
            let confirmMsg = ChatMessage(
                sender: .assistant,
                text: "✅ **Success!** Safely moved \(result.succeeded) items (**\(formatted)**) to your macOS Trash. Your disk space has been reclaimed!"
            )
            messages.append(confirmMsg)

        case .cleanCategory(let cat, let size):
            let result = scanner.cleanSelected(in: cat)
            let formatted = ByteCountFormatter.string(fromByteCount: result.bytesFreed > 0 ? result.bytesFreed : size, countStyle: .file)
            let confirmMsg = ChatMessage(
                sender: .assistant,
                text: "✅ **Cleaned \(cat.rawValue)!** Safely moved \(result.succeeded) items (**\(formatted)**) to macOS Trash."
            )
            messages.append(confirmMsg)

        case .trashItem(let url, let name, let size):
            do {
                var resultingURL: NSURL?
                try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
                let formatted = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
                // Remove from scanner
                for cat in scanner.itemsByCategory.keys {
                    scanner.itemsByCategory[cat]?.removeAll { $0.url == url }
                }
                scanner.recalculateCleanableBytes()
                scanner.refreshDiskSpace()

                let confirmMsg = ChatMessage(
                    sender: .assistant,
                    text: "✅ **Moved to Trash:** '\(name)' (\(formatted)). You can restore it anytime from your Trash folder."
                )
                messages.append(confirmMsg)
            } catch {
                let errorMsg = ChatMessage(
                    sender: .assistant,
                    text: "⚠️ **Could not delete:** \(error.localizedDescription)"
                )
                messages.append(errorMsg)
            }

        case .navigateCategory(let cat):
            WindowManager.shared.openCategory(cat)

        case .rescan:
            Task {
                await scanner.scanQuickCleanDashboard()
                let cleanable = ByteCountFormatter.string(fromByteCount: scanner.totalCleanableBytes, countStyle: .file)
                let confirmMsg = ChatMessage(
                    sender: .assistant,
                    text: "🔄 **Scan Finished!** Found \(cleanable) of cleanable junk."
                )
                self.messages.append(confirmMsg)
            }
        }
    }
}
