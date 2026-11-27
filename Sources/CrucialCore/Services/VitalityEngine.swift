import Foundation

public final class VitalityEngine: Sendable {
    public static let shared = VitalityEngine()

    private let protectedPrefixes: [String] = [
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/private/var",
        "/Library/Extensions",
        "/Library/KernelExtensions",
        "/Applications"
    ]

    private let protectedExtensions: Set<String> = [
        "swift", "rs", "go", "py", "ts", "js", "cpp", "c", "h", "java", "kt",
        "keychain", "plist", "app", "framework", "kext"
    ]

    private init() {}

    public func assess(url: URL, size: Int64 = 0, isDirectory: Bool = false) -> VitalityAssessment {
        let path = url.path
        let resolvedPath = url.resolvingSymlinksInPath().path
        let filename = url.lastPathComponent
        let ext = url.pathExtension.lowercased()

        // 1. Protect critical OS paths and any symlink pointing into them
        for prefix in protectedPrefixes {
            if path.hasPrefix(prefix) || resolvedPath.hasPrefix(prefix) {
                return VitalityAssessment(
                    level: .vital,
                    riskScore: 99,
                    category: .custom,
                    summary: "macOS Core System File or Application",
                    impact: "Essential to operating system stability or installed software. Protected from deletion.",
                    canBeRebuilt: false,
                    rebuildCommand: nil,
                    aiGenerated: false
                )
            }
        }

        // 2. Git Version Control Integrity
        if filename == ".git" || path.contains("/.git/") {
            return VitalityAssessment(
                level: .vital,
                riskScore: 95,
                category: .custom,
                summary: "Git Version Control Repository",
                impact: "Contains commit history, branches, and remote configuration. Deleting this destroys local version control.",
                canBeRebuilt: false,
                rebuildCommand: nil,
                aiGenerated: false
            )
        }

        // 3. Personal Source Code & Documents
        let home = URL.homeDirectory.path
        if (path.hasPrefix("\(home)/Documents") || path.hasPrefix("\(home)/Desktop")) && protectedExtensions.contains(ext) {
            return VitalityAssessment(
                level: .vital,
                riskScore: 90,
                category: .custom,
                summary: "Personal Document or Source File",
                impact: "Active user file that cannot be automatically regenerated.",
                canBeRebuilt: false,
                rebuildCommand: nil,
                aiGenerated: false
            )
        }

        // 4. Developer Build Caches
        if filename == "node_modules" {
            return VitalityAssessment(
                level: .safeToDelete,
                riskScore: 5,
                category: .devArtifacts,
                summary: "Node.js Package Dependencies (node_modules)",
                impact: "Cached project dependencies. Source code and package manifests remain untouched.",
                canBeRebuilt: true,
                rebuildCommand: "npm install",
                aiGenerated: false
            )
        }

        if path.contains("/Library/Developer/Xcode/DerivedData") || filename == "DerivedData" {
            return VitalityAssessment(
                level: .safeToDelete,
                riskScore: 2,
                category: .devArtifacts,
                summary: "Xcode Build Cache (DerivedData)",
                impact: "Intermediate compilation products and indexes. Xcode regenerates these automatically on the next build.",
                canBeRebuilt: true,
                rebuildCommand: "xcodebuild -clean",
                aiGenerated: false
            )
        }

        if filename == "target" && FileManager.default.fileExists(atPath: url.deletingLastPathComponent().appending(path: "Cargo.toml").path) {
            return VitalityAssessment(
                level: .safeToDelete,
                riskScore: 4,
                category: .devArtifacts,
                summary: "Rust Cargo Build Artifacts (target)",
                impact: "Compiled binaries and incremental cache. Can be cleanly rebuilt with cargo.",
                canBeRebuilt: true,
                rebuildCommand: "cargo build",
                aiGenerated: false
            )
        }

        if filename == ".venv" || filename == "venv" || filename == "__pycache__" || filename == ".pytest_cache" {
            return VitalityAssessment(
                level: .safeToDelete,
                riskScore: 8,
                category: .devArtifacts,
                summary: "Python Virtual Environment or Bytecode Cache",
                impact: "Cached bytecode and environment packages. Re-installable from requirements or lockfiles.",
                canBeRebuilt: true,
                rebuildCommand: "python3 -m venv .venv && pip install -r requirements.txt",
                aiGenerated: false
            )
        }

        // 5. System & User Application Caches
        if path.contains("/Library/Caches/") {
            let appName = url.pathComponents.first(where: { $0.contains(".") || $0.contains("Cache") }) ?? "Application"
            return VitalityAssessment(
                level: .safeToDelete,
                riskScore: 10,
                category: .systemCache,
                summary: "\(appName) Cache Store",
                impact: "Disposable cached assets. Applications recreate required caches automatically.",
                canBeRebuilt: true,
                rebuildCommand: "Recreated automatically on next app launch",
                aiGenerated: false
            )
        }

        // 6. Diagnostic Logs & Crash Reports
        if path.contains("/Library/Logs/") || ext == "log" || ext == "crash" || ext == "ips" {
            return VitalityAssessment(
                level: .safeToDelete,
                riskScore: 3,
                category: .systemCache,
                summary: "Diagnostic Log or Crash Report",
                impact: "Historical log output with no impact on running software.",
                canBeRebuilt: false,
                rebuildCommand: nil,
                aiGenerated: false
            )
        }

        // 7. Downloaded Installers & Archives
        if path.contains("/Downloads/") && (ext == "dmg" || ext == "pkg" || ext == "iso") {
            return VitalityAssessment(
                level: .safeToDelete,
                riskScore: 12,
                category: .largeUnused,
                summary: "Software Installer Archive (\(ext.uppercased()))",
                impact: "Standalone disk image or package installer no longer required after installation.",
                canBeRebuilt: true,
                rebuildCommand: "Re-download from software vendor if needed",
                aiGenerated: false
            )
        }

        // 8. Application Support Residue
        if path.contains("/Library/Application Support/") {
            let component = url.lastPathComponent
            let possibleAppPath = "/Applications/\(component).app"
            let possibleSysAppPath = "/System/Applications/\(component).app"
            let appInstalled = FileManager.default.fileExists(atPath: possibleAppPath) || FileManager.default.fileExists(atPath: possibleSysAppPath)

            if !appInstalled && !component.lowercased().contains("apple") {
                return VitalityAssessment(
                    level: .safeToDelete,
                    riskScore: 15,
                    category: .appResidue,
                    summary: "Orphaned Residue from \(component)",
                    impact: "Support folder left behind after the parent application was removed.",
                    canBeRebuilt: false,
                    rebuildCommand: nil,
                    aiGenerated: false
                )
            } else {
                return VitalityAssessment(
                    level: .caution,
                    riskScore: 60,
                    category: .appResidue,
                    summary: "Active Application Support Data for \(component)",
                    impact: "May hold preferences or local databases for an installed application. Review before trashing.",
                    canBeRebuilt: false,
                    rebuildCommand: nil,
                    aiGenerated: false
                )
            }
        }

        return VitalityAssessment(
            level: .caution,
            riskScore: 50,
            category: .custom,
            summary: "User Data (\(filename))",
            impact: "Review contents or preview with Quick Look before moving to Trash.",
            canBeRebuilt: false,
            rebuildCommand: nil,
            aiGenerated: false
        )
    }
}
