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
        let filename = url.lastPathComponent
        let ext = url.pathExtension.lowercased()

        // 1. Critical System & OS Protected Paths
        for prefix in protectedPrefixes {
            if path.hasPrefix(prefix) {
                return VitalityAssessment(
                    level: .vital,
                    riskScore: 99,
                    category: .custom,
                    summary: "macOS Core System File / Binary",
                    impact: "Critical to operating system stability. Cannot and should not be deleted.",
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
                impact: "Contains your commit history, branches, and remote configuration. Deleting this destroys local version control.",
                canBeRebuilt: false,
                rebuildCommand: nil,
                aiGenerated: false
            )
        }

        // 3. User Personal Source Code & Documents
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if (path.hasPrefix("\(home)/Documents") || path.hasPrefix("\(home)/Desktop")) && protectedExtensions.contains(ext) {
            return VitalityAssessment(
                level: .vital,
                riskScore: 90,
                category: .custom,
                summary: "Personal User Document / Source Code",
                impact: "Active personal user file. Essential data that cannot be recovered automatically.",
                canBeRebuilt: false,
                rebuildCommand: nil,
                aiGenerated: false
            )
        }

        // 4. Developer Build Caches (Safe to delete, high volume)
        if filename == "node_modules" {
            return VitalityAssessment(
                level: .safeToDelete,
                riskScore: 5,
                category: .devArtifacts,
                summary: "Node.js Package Dependencies (node_modules)",
                impact: "Build artifact taking up substantial disk space. Safe to delete whenever not actively working on this project.",
                canBeRebuilt: true,
                rebuildCommand: "npm install (or pnpm / yarn install)",
                aiGenerated: false
            )
        }

        if path.contains("/Library/Developer/Xcode/DerivedData") || filename == "DerivedData" {
            return VitalityAssessment(
                level: .safeToDelete,
                riskScore: 2,
                category: .devArtifacts,
                summary: "Xcode Build Cache (DerivedData)",
                impact: "Intermediate compilation artifacts, indexes, and logs. Xcode automatically regenerates this upon next build.",
                canBeRebuilt: true,
                rebuildCommand: "Xcode re-indexes and rebuilds automatically.",
                aiGenerated: false
            )
        }

        if filename == "target" && (FileManager.default.fileExists(atPath: url.deletingLastPathComponent().appendingPathComponent("Cargo.toml").path)) {
            return VitalityAssessment(
                level: .safeToDelete,
                riskScore: 4,
                category: .devArtifacts,
                summary: "Rust Cargo Build Artifacts (target/)",
                impact: "Compiled binaries, dependencies, and incremental build cache. Can be cleanly rebuilt with cargo build.",
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
                summary: "Python Virtual Environment / Bytecode Cache",
                impact: "Cached python bytecode and virtual environment packages. Re-installable using your requirements.txt or pyproject.toml.",
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
                summary: "\(appName) Cache File",
                impact: "Temporary data cached for speed. The application will fetch or recreate necessary cache items automatically.",
                canBeRebuilt: true,
                rebuildCommand: "Recreated by application as needed.",
                aiGenerated: false
            )
        }

        // 6. Old Logs and Crash Reports
        if path.contains("/Library/Logs/") || ext == "log" || ext == "crash" || ext == "ips" {
            return VitalityAssessment(
                level: .safeToDelete,
                riskScore: 3,
                category: .systemCache,
                summary: "Historical Diagnostic Log / Crash Report",
                impact: "Diagnostics from past application sessions. Deleting logs has zero impact on application functionality.",
                canBeRebuilt: false,
                rebuildCommand: nil,
                aiGenerated: false
            )
        }

        // 7. Download Installers & Old Archives
        if path.contains("/Downloads/") && (ext == "dmg" || ext == "pkg" || ext == "iso") {
            return VitalityAssessment(
                level: .safeToDelete,
                riskScore: 12,
                category: .largeUnused,
                summary: "Downloaded Software Installer (\(ext.uppercased()))",
                impact: "Installation disk image or package. If the application is already installed, this installer is no longer needed.",
                canBeRebuilt: true,
                rebuildCommand: "Re-download from the developer's website if ever required.",
                aiGenerated: false
            )
        }

        // 8. Orphaned Application Residue
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
                    impact: "Leftover support files from an application that is no longer found in your Applications directory.",
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
                    impact: "Contains user preferences, local databases, or extensions for an installed app. Only delete if resetting the app.",
                    canBeRebuilt: false,
                    rebuildCommand: nil,
                    aiGenerated: false
                )
            }
        }

        // Default: Caution for general files
        return VitalityAssessment(
            level: .caution,
            riskScore: 50,
            category: .custom,
            summary: "User File / Data (\(filename))",
            impact: "Review before deleting. Verify you no longer need this file before moving it to Trash.",
            canBeRebuilt: false,
            rebuildCommand: nil,
            aiGenerated: false
        )
    }
}
