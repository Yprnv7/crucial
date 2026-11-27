import AppKit
import Foundation

public final class FileDiagnosticEngine: Sendable {
    public static let shared = FileDiagnosticEngine()

    private init() {}

    public func profile(item: FileItem) async -> DetailedFileProfile {
        let path = item.path
        let name = item.name
        let size = item.size
        let isDir = item.isDirectory
        let modDateStr = item.modificationDate?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown"
        let fileCount = isDir ? await FileSystemSizer.boundedFileCount(at: item.url, limit: 5000) : 1
        let runningNames = await MainActor.run {
            Set(NSWorkspace.shared.runningApplications.compactMap { $0.localizedName?.lowercased() })
        }

        return buildProfile(
            item: item,
            path: path,
            name: name,
            size: size,
            isDir: isDir,
            fileCount: fileCount,
            modDateStr: modDateStr,
            runningAppNames: runningNames
        )
    }

    private func buildProfile(
        item: FileItem,
        path: String,
        name: String,
        size: Int64,
        isDir: Bool,
        fileCount: Int,
        modDateStr: String,
        runningAppNames: Set<String>
    ) -> DetailedFileProfile {
        let p = path.lowercased()
        let parentDir = item.url.deletingLastPathComponent().path

        if p.contains("developer/xcode/deriveddata") {
            let running = runningAppNames.contains(where: { $0.contains("xcode") })
            return DetailedFileProfile(
                name: name,
                path: path,
                parentDirectory: parentDir,
                formattedSize: item.formattedSize,
                exactBytes: size,
                isDirectory: isDir,
                fileCount: fileCount,
                lastModified: modDateStr,
                daysIdle: item.daysSinceLastAccess,
                createdByApp: "Apple Xcode (LLVM / swiftc toolchain)",
                fileClassification: "Precompiled LLVM Objects, AST Module Caches & Indexes",
                subsystemOrigin: "Developer Tools: Build System & SourceKit Indexer",
                functionalPurpose: "Caches compiled object files (.o, .swiftmodule), indexing databases, and build logs to accelerate incremental builds.",
                whyItExists: "Xcode stores per-project build caches separately and rarely prunes stale workspace hashes automatically.",
                activeProcessDependency: running ? "Xcode is currently active. Close active builds before cleaning." : "Xcode (idle / not running).",
                isProcessRunning: running,
                canBeDeleted: true,
                deletionVerdict: "Safe to Purge: 100% Disposable Build Cache",
                immediateImpact: "Reclaims \(item.formattedSize) immediately and resolves stale indexing or dirty build caches.",
                appRelaunchImpact: "Next build recompiles target modules cleanly. Source files and Git history are untouched.",
                rebuildCommand: "xcodebuild -clean",
                vitalityRiskScore: 2,
                bloatSeverityScore: calculateBloatScore(size: size, daysIdle: item.daysSinceLastAccess),
                recoveryDifficultyScore: 5,
                safetyConfidencePercent: 99
            )
        }

        if p.contains("node_modules") {
            let running = runningAppNames.contains(where: { $0.contains("node") || $0.contains("code") })
            return DetailedFileProfile(
                name: name,
                path: path,
                parentDirectory: parentDir,
                formattedSize: item.formattedSize,
                exactBytes: size,
                isDirectory: true,
                fileCount: fileCount,
                lastModified: modDateStr,
                daysIdle: item.daysSinceLastAccess,
                createdByApp: "Node.js Package Manager (npm / pnpm / yarn)",
                fileClassification: "Third-Party JavaScript & TypeScript Dependencies",
                subsystemOrigin: "Web & Node Ecosystem: Local Package Tree",
                functionalPurpose: "Holds installed external packages declared in package.json for local builds and dev servers.",
                whyItExists: "JavaScript projects store isolated dependency trees per repository, accumulating large trees in dormant projects.",
                activeProcessDependency: running ? "A development editor or Node server may be running." : "Node.js toolchain (idle).",
                isProcessRunning: running,
                canBeDeleted: true,
                deletionVerdict: "Safe to Purge (When Project is Idle)",
                immediateImpact: "Frees \(item.formattedSize) and thousands of small files without affecting tracked source code.",
                appRelaunchImpact: "Local builds require reinstalling dependencies via npm, pnpm, or yarn.",
                rebuildCommand: "cd \"\(parentDir)\" && npm install",
                vitalityRiskScore: 8,
                bloatSeverityScore: calculateBloatScore(size: size, daysIdle: item.daysSinceLastAccess),
                recoveryDifficultyScore: 10,
                safetyConfidencePercent: 99
            )
        }

        if p.contains("library/caches") {
            let appName = parseAppNameFromCache(path: path)
            let running = !appName.isEmpty && appName != "Application" && runningAppNames.contains(where: { $0.contains(appName.lowercased()) })
            return DetailedFileProfile(
                name: name,
                path: path,
                parentDirectory: parentDir,
                formattedSize: item.formattedSize,
                exactBytes: size,
                isDirectory: isDir,
                fileCount: fileCount,
                lastModified: modDateStr,
                daysIdle: item.daysSinceLastAccess,
                createdByApp: appName.isEmpty ? "macOS User Application" : appName,
                fileClassification: "Disk-Backed HTTP, Media & Asset Cache",
                subsystemOrigin: "Application Sandbox: Cache Storage",
                functionalPurpose: "Stores temporary downloaded media thumbnails, web fonts, and HTTP responses for faster rendering.",
                whyItExists: "Apple macOS sandbox guidelines designate ~/Library/Caches strictly for dispensable, regenerable files.",
                activeProcessDependency: running ? "\(appName) is currently open and may recreate entries immediately." : "\(appName) (not running).",
                isProcessRunning: running,
                canBeDeleted: true,
                deletionVerdict: "Safe to Purge: Regenerable Application Cache",
                immediateImpact: "Reclaims \(item.formattedSize). User accounts, passwords, and documents are not stored here.",
                appRelaunchImpact: "The application rebuilds cache entries on demand during normal use.",
                rebuildCommand: "Automatic: \(appName) regenerates caches upon launch",
                vitalityRiskScore: 5,
                bloatSeverityScore: calculateBloatScore(size: size, daysIdle: item.daysSinceLastAccess),
                recoveryDifficultyScore: 0,
                safetyConfidencePercent: 99
            )
        }

        if p.contains("library/application support") {
            let orphanName = item.name.replacing("Orphan: ", with: "")
            return DetailedFileProfile(
                name: name,
                path: path,
                parentDirectory: parentDir,
                formattedSize: item.formattedSize,
                exactBytes: size,
                isDirectory: isDir,
                fileCount: fileCount,
                lastModified: modDateStr,
                daysIdle: item.daysSinceLastAccess,
                createdByApp: "\(orphanName) (Previously Installed Application)",
                fileClassification: "Application Support Data & Legacy Databases",
                subsystemOrigin: "Application Support: Residue Audit",
                functionalPurpose: "Retained configuration, assets, and storage containers associated with '\(orphanName)'.",
                whyItExists: "Dragging an app to Trash removes only the .app bundle while leaving its ~/Library support folder behind.",
                activeProcessDependency: "None. No matching bundle found in /Applications.",
                isProcessRunning: false,
                canBeDeleted: true,
                deletionVerdict: "High Priority Cleanup: Orphaned App Residue",
                immediateImpact: "Moves \(item.formattedSize) of unused support files to Trash.",
                appRelaunchImpact: "None when the parent application has already been removed.",
                rebuildCommand: nil,
                vitalityRiskScore: 3,
                bloatSeverityScore: 92,
                recoveryDifficultyScore: 0,
                safetyConfidencePercent: 99
            )
        }

        if p.contains("downloads") {
            let ext = item.url.pathExtension.uppercased()
            return DetailedFileProfile(
                name: name,
                path: path,
                parentDirectory: parentDir,
                formattedSize: item.formattedSize,
                exactBytes: size,
                isDirectory: isDir,
                fileCount: 1,
                lastModified: modDateStr,
                daysIdle: item.daysSinceLastAccess,
                createdByApp: "Web Browser / macOS Downloader",
                fileClassification: "\(ext.isEmpty ? "Archive" : ext) Installer or Archive",
                subsystemOrigin: "User Downloads Directory",
                functionalPurpose: "Downloaded disk image, archive, or installation package.",
                whyItExists: "Installers often remain in Downloads indefinitely after software has been copied to /Applications.",
                activeProcessDependency: "None. File is dormant.",
                isProcessRunning: false,
                canBeDeleted: true,
                deletionVerdict: item.daysSinceLastAccess > 30 ? "Safe Review: Stale Download" : "Caution: Review Contents First",
                immediateImpact: "Frees \(item.formattedSize) immediately via Trash staging.",
                appRelaunchImpact: "Installed applications continue working normally.",
                rebuildCommand: "Re-download from vendor website if required later",
                vitalityRiskScore: item.daysSinceLastAccess > 30 ? 12 : 35,
                bloatSeverityScore: calculateBloatScore(size: size, daysIdle: item.daysSinceLastAccess),
                recoveryDifficultyScore: 25,
                safetyConfidencePercent: 95
            )
        }

        let isSystem = p.hasPrefix("/system") || p.hasPrefix("/usr") || p.hasPrefix("/bin") || p.contains("library/preferences")
        return DetailedFileProfile(
            name: name,
            path: path,
            parentDirectory: parentDir,
            formattedSize: item.formattedSize,
            exactBytes: size,
            isDirectory: isDir,
            fileCount: fileCount,
            lastModified: modDateStr,
            daysIdle: item.daysSinceLastAccess,
            createdByApp: isSystem ? "Apple macOS Operating System" : "User Workflow",
            fileClassification: isSystem ? "Protected System Resource" : "General User File",
            subsystemOrigin: isSystem ? "System Integrity Protection" : "User Home Directory",
            functionalPurpose: isSystem ? "Core macOS binary, framework, or system preference configuration." : "User-created document or workspace file.",
            whyItExists: isSystem ? "Required component of the macOS operating environment." : "Saved by a user application.",
            activeProcessDependency: isSystem ? "macOS System Daemons" : "No live lock verified.",
            isProcessRunning: isSystem,
            canBeDeleted: !isSystem,
            deletionVerdict: isSystem ? "Protected: Critical System File" : "Review Carefully Before Removing",
            immediateImpact: isSystem ? "Blocked by Crucial Safety Lock to preserve system stability." : "Moves \(item.formattedSize) to macOS Trash.",
            appRelaunchImpact: isSystem ? "Not deletable." : "Restore from Trash if still needed.",
            rebuildCommand: nil,
            vitalityRiskScore: isSystem ? 98 : 65,
            bloatSeverityScore: 10,
            recoveryDifficultyScore: isSystem ? 100 : 70,
            safetyConfidencePercent: 99
        )
    }

    private func calculateBloatScore(size: Int64, daysIdle: Int) -> Int {
        let gb = Double(size) / (1024 * 1024 * 1024)
        let sizeScore = min(60.0, gb * 30.0)
        let ageScore = min(40.0, Double(daysIdle) * 1.2)
        return Int(min(100.0, sizeScore + ageScore))
    }

    private func parseAppNameFromCache(path: String) -> String {
        let components = path.components(separatedBy: "/")
        if let idx = components.firstIndex(of: "Caches"), idx + 1 < components.count {
            let folder = components[idx + 1]
            if folder.contains(".") {
                return folder.components(separatedBy: ".").last?.capitalized ?? folder
            }
            return folder.capitalized
        }
        return "Application"
    }
}
