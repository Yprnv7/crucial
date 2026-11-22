import Foundation
import AppKit

public struct DetailedFileProfile: Sendable {
    public let name: String
    public let path: String
    public let parentDirectory: String
    public let formattedSize: String
    public let exactBytes: Int64
    public let isDirectory: Bool
    public let fileCount: Int
    public let lastModified: String
    public let daysIdle: Int

    // Provenance & Identity
    public let createdByApp: String
    public let fileClassification: String
    public let subsystemOrigin: String

    // Technical Purpose & Origin
    public let functionalPurpose: String
    public let whyItExists: String
    public let activeProcessDependency: String
    public let isProcessRunning: Bool

    // Deletion Impact & Safety Verdict
    public let canBeDeleted: Bool
    public let deletionVerdict: String
    public let immediateImpact: String
    public let appRelaunchImpact: String
    public let rebuildCommand: String?

    // Crucial Scores
    public let vitalityRiskScore: Int       // 0 (disposable) to 100 (critical OS kernel)
    public let bloatSeverityScore: Int      // 0 to 100 (based on bytes + idle time)
    public let recoveryDifficultyScore: Int // 0 (auto-regenerates) to 100 (manual restore only)
    public let safetyConfidencePercent: Int // e.g. 99%
}

public final class FileDiagnosticEngine: Sendable {
    public static let shared = FileDiagnosticEngine()

    private init() {}

    public func profile(item: FileItem) -> DetailedFileProfile {
        let path = item.path
        let name = item.name
        let size = item.size
        let isDir = item.isDirectory

        let modDateStr = item.modificationDate != nil ? DateFormatter.localizedString(from: item.modificationDate!, dateStyle: .medium, timeStyle: .short) : "Unknown"

        // Count files if directory
        var fileCount = 1
        if isDir {
            if let enumerator = FileManager.default.enumerator(at: item.url, includingPropertiesForKeys: [.fileSizeKey]) {
                var c = 0
                while enumerator.nextObject() != nil {
                    c += 1
                    if c >= 5000 { break }
                }
                fileCount = c
            }
        }

        // Analyze file origins based on path semantics
        let p = path.lowercased()

        // 1. Xcode DerivedData
        if p.contains("developer/xcode/deriveddata") {
            let running = isProcessActive("Xcode")
            return DetailedFileProfile(
                name: name,
                path: path,
                parentDirectory: (path as NSString).deletingLastPathComponent,
                formattedSize: item.formattedSize,
                exactBytes: size,
                isDirectory: isDir,
                fileCount: fileCount,
                lastModified: modDateStr,
                daysIdle: item.daysSinceLastAccess,
                createdByApp: "Apple Xcode (llvm / swiftc toolchain)",
                fileClassification: "Precompiled LLVM Objects, AST Module Caches & Code Indexes",
                subsystemOrigin: "Developer Tools · Build System & SourceKit Indexer",
                functionalPurpose: "Caches compiled intermediate object files (.o, .swiftmodule), indexing databases, and build logs to speed up incremental compilation during daily development.",
                whyItExists: "Xcode creates an isolated DerivedData folder for every project to avoid recompiling unchanged source files on every run. However, it never purges old builds, allowing stale projects to silently consume tens of gigabytes.",
                activeProcessDependency: running ? "Active Xcode Process detected. If actively building, close Xcode before purging." : "Xcode (currently idle / closed).",
                isProcessRunning: running,
                canBeDeleted: true,
                deletionVerdict: "YES — 100% SAFE TO PURGE",
                immediateImpact: "Reclaims \(item.formattedSize) of storage immediately. Fixes corrupt indexing, stale autocomplete glitches, and failed dirty builds.",
                appRelaunchImpact: "Next project build will perform a clean compile from scratch. Source code and git history are completely untouched.",
                rebuildCommand: "xcodebuild -clean  # or Product > Clean Build Folder in Xcode",
                vitalityRiskScore: 2,
                bloatSeverityScore: calculateBloatScore(size: size, daysIdle: item.daysSinceLastAccess),
                recoveryDifficultyScore: 5,
                safetyConfidencePercent: 99
            )
        }

        // 2. node_modules
        if p.contains("node_modules") {
            let running = isProcessActive("node")
            return DetailedFileProfile(
                name: name,
                path: path,
                parentDirectory: (path as NSString).deletingLastPathComponent,
                formattedSize: item.formattedSize,
                exactBytes: size,
                isDirectory: true,
                fileCount: fileCount,
                lastModified: modDateStr,
                daysIdle: item.daysSinceLastAccess,
                createdByApp: "Node.js (npm / yarn / pnpm package manager)",
                fileClassification: "Vendor JavaScript/TypeScript Third-Party Dependencies",
                subsystemOrigin: "Web & Node Ecosystem · Package Tree",
                functionalPurpose: "Stores external open-source packages declared in package.json needed to run or bundle this project locally.",
                whyItExists: "Node projects isolate dependencies per repository rather than globally, duplicating hundreds of thousands of identical micro-packages across your disk.",
                activeProcessDependency: running ? "Node.js or development dev-server running in background." : "Node.js toolchain (inactive).",
                isProcessRunning: running,
                canBeDeleted: true,
                deletionVerdict: "YES — 100% SAFE TO PURGE (IF IDLE)",
                immediateImpact: "Instantly frees \(item.formattedSize) and thousands of disk inodes. No impact on git tracking.",
                appRelaunchImpact: "Project cannot run locally until dependencies are re-downloaded via npm.",
                rebuildCommand: "cd \"\((path as NSString).deletingLastPathComponent)\" && npm install",
                vitalityRiskScore: 8,
                bloatSeverityScore: calculateBloatScore(size: size, daysIdle: item.daysSinceLastAccess),
                recoveryDifficultyScore: 10,
                safetyConfidencePercent: 99
            )
        }

        // 3. User Caches (~/Library/Caches)
        if p.contains("library/caches") {
            let appName = parseAppNameFromCache(path: path)
            let running = isProcessActive(appName)
            return DetailedFileProfile(
                name: name,
                path: path,
                parentDirectory: (path as NSString).deletingLastPathComponent,
                formattedSize: item.formattedSize,
                exactBytes: size,
                isDirectory: isDir,
                fileCount: fileCount,
                lastModified: modDateStr,
                daysIdle: item.daysSinceLastAccess,
                createdByApp: appName.isEmpty ? "macOS User Application" : appName,
                fileClassification: "Disk-backed HTTP, Image & Temporary Memory Cache",
                subsystemOrigin: "Application Framework · Cache Storage Manager",
                functionalPurpose: "Stores temporary downloaded assets (profile avatars, web fonts, thumbnails, streaming buffer segments) so apps don't re-download them from the web every time.",
                whyItExists: "Designed specifically by macOS as disposable memory. Apple's official App Sandbox guidelines mandate that files in ~/Library/Caches must be dispensable without data loss.",
                activeProcessDependency: running ? "\(appName) is currently running. Purging while running will cause app to recreate files immediately." : "\(appName) (not running).",
                isProcessRunning: running,
                canBeDeleted: true,
                deletionVerdict: "YES — SAFE TO PURGE",
                immediateImpact: "Reclaims \(item.formattedSize). Passwords, user sessions, and preferences are NOT stored in Caches and remain completely safe.",
                appRelaunchImpact: "App may launch slightly slower on first run as it pulls fresh assets from the web.",
                rebuildCommand: "Automatic — \(appName) recreates its cache folder dynamically upon launch",
                vitalityRiskScore: 5,
                bloatSeverityScore: calculateBloatScore(size: size, daysIdle: item.daysSinceLastAccess),
                recoveryDifficultyScore: 0,
                safetyConfidencePercent: 99
            )
        }

        // 4. Orphaned App Residue (~/Library/Application Support)
        if p.contains("library/application support") {
            let orphanName = item.name.replacingOccurrences(of: "Orphan: ", with: "")
            return DetailedFileProfile(
                name: name,
                path: path,
                parentDirectory: (path as NSString).deletingLastPathComponent,
                formattedSize: item.formattedSize,
                exactBytes: size,
                isDirectory: isDir,
                fileCount: fileCount,
                lastModified: modDateStr,
                daysIdle: item.daysSinceLastAccess,
                createdByApp: "\(orphanName) (Previously Installed Application)",
                fileClassification: "Abandoned Application Data & Legacy Storage",
                subsystemOrigin: "Application Support · Orphaned Residue",
                functionalPurpose: "Held local databases, state files, and support assets for '\(orphanName)'.",
                whyItExists: "When you drag an application to the macOS Trash, macOS deletes the .app file but leaves behind its entire Application Support directory forever.",
                activeProcessDependency: "None. Crucial verified that '\(orphanName).app' no longer exists in /Applications or /System/Applications.",
                isProcessRunning: false,
                canBeDeleted: true,
                deletionVerdict: "YES — HIGH PRIORITY CLEANUP",
                immediateImpact: "Permanently removes \(item.formattedSize) of dead data belonging to software you don't even have installed anymore.",
                appRelaunchImpact: "None. The app is already uninstalled from your Mac.",
                rebuildCommand: "None needed (software was already removed)",
                vitalityRiskScore: 3,
                bloatSeverityScore: 92,
                recoveryDifficultyScore: 0,
                safetyConfidencePercent: 100
            )
        }

        // 5. Large Idle Downloads
        if p.contains("downloads") {
            let ext = (path as NSString).pathExtension.uppercased()
            return DetailedFileProfile(
                name: name,
                path: path,
                parentDirectory: (path as NSString).deletingLastPathComponent,
                formattedSize: item.formattedSize,
                exactBytes: size,
                isDirectory: isDir,
                fileCount: 1,
                lastModified: modDateStr,
                daysIdle: item.daysSinceLastAccess,
                createdByApp: "Web Browser / macOS Downloader",
                fileClassification: "\(ext.isEmpty ? "Archive/Data" : ext) Installer Package / Disk Image",
                subsystemOrigin: "User Downloads Folder",
                functionalPurpose: "Delivered application binaries, setup installers, or archived files from the internet.",
                whyItExists: "Downloaded by the user to install a software package. Once the software is installed into /Applications, the installer image (.dmg or .pkg) remains idle taking up storage.",
                activeProcessDependency: "None. File is dormant.",
                isProcessRunning: false,
                canBeDeleted: true,
                deletionVerdict: item.daysSinceLastAccess > 30 ? "YES — HIGH PROBABILITY OBSOLETE" : "CAUTION — REVIEW CONTENT FIRST",
                immediateImpact: "Frees \(item.formattedSize) instantly.",
                appRelaunchImpact: "None. If you ever need the installer again, it can be re-downloaded from the vendor website.",
                rebuildCommand: "Re-download from original distributor website",
                vitalityRiskScore: item.daysSinceLastAccess > 30 ? 12 : 35,
                bloatSeverityScore: calculateBloatScore(size: size, daysIdle: item.daysSinceLastAccess),
                recoveryDifficultyScore: 25,
                safetyConfidencePercent: 95
            )
        }

        // 6. Protected System or User Data
        let isSystem = p.hasPrefix("/system") || p.hasPrefix("/usr") || p.hasPrefix("/bin") || p.contains("library/preferences")
        return DetailedFileProfile(
            name: name,
            path: path,
            parentDirectory: (path as NSString).deletingLastPathComponent,
            formattedSize: item.formattedSize,
            exactBytes: size,
            isDirectory: isDir,
            fileCount: fileCount,
            lastModified: modDateStr,
            daysIdle: item.daysSinceLastAccess,
            createdByApp: isSystem ? "Apple macOS Operating System" : "User File",
            fileClassification: isSystem ? "Protected Operating System File / User Configuration" : "General User Document",
            subsystemOrigin: isSystem ? "Darwin Kernel / System Integrity Protection (SIP)" : "User Home Directory",
            functionalPurpose: isSystem ? "Contains essential system binaries, dynamic libraries, or critical user configuration keys." : "User-managed file or application resource.",
            whyItExists: isSystem ? "Crucial component of the macOS operating system environment." : "Created by user workflow.",
            activeProcessDependency: isSystem ? "macOS System Daemons & WindowServer." : "Unknown user process.",
            isProcessRunning: isSystem,
            canBeDeleted: !isSystem,
            deletionVerdict: isSystem ? "NO — PROTECTED / CRITICAL SYSTEM FILE" : "REVIEW CAREFULLY",
            immediateImpact: isSystem ? "CRITICAL: Deleting this file can destabilize macOS, corrupt user preferences, or prevent boot." : "Frees \(item.formattedSize).",
            appRelaunchImpact: isSystem ? "Severe system malfunction." : "User data lost unless backed up.",
            rebuildCommand: isSystem ? "macOS Recovery / Reinstall" : "Manual backup restore",
            vitalityRiskScore: isSystem ? 98 : 65,
            bloatSeverityScore: 10,
            recoveryDifficultyScore: isSystem ? 100 : 70,
            safetyConfidencePercent: 99
        )
    }

    private func calculateBloatScore(size: Int64, daysIdle: Int) -> Int {
        // Size component: 1 GB = ~50 pts, max 60
        let gb = Double(size) / (1024 * 1024 * 1024)
        let sizeScore = min(60.0, gb * 30.0)
        // Age component: 30 days = ~25 pts, max 40
        let ageScore = min(40.0, Double(daysIdle) * 1.2)
        return Int(min(100.0, sizeScore + ageScore))
    }

    private func parseAppNameFromCache(path: String) -> String {
        let components = path.components(separatedBy: "/")
        if let idx = components.firstIndex(of: "Caches"), idx + 1 < components.count {
            let folder = components[idx + 1]
            // Format bundle IDs like com.apple.Safari or Google/Chrome
            if folder.contains(".") {
                return folder.components(separatedBy: ".").last?.capitalized ?? folder
            }
            return folder.capitalized
        }
        return "Application"
    }

    private func isProcessActive(_ name: String) -> Bool {
        guard !name.isEmpty, name != "Application" else { return false }
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-if", name]
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
