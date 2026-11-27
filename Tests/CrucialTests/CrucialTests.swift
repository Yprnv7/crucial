import CrucialCore
import Foundation
import Testing

@Suite("Vitality Engine Safety Rules")
struct VitalityEngineTests {
    @Test("Protects /System paths as vital")
    func protectsSystemRoot() {
        let assessment = VitalityEngine.shared.assess(
            url: URL(filePath: "/System/Library/CoreServices/Finder.app"),
            size: 1_024,
            isDirectory: true
        )
        #expect(assessment.level == .vital)
        #expect(assessment.canBeRebuilt == false)
    }

    @Test("Protects .git metadata repositories")
    func protectsGitRepo() {
        let assessment = VitalityEngine.shared.assess(
            url: URL(filePath: "/tmp/sample-project/.git"),
            size: 4_096,
            isDirectory: true
        )
        #expect(assessment.level == .vital)
        #expect(assessment.riskScore >= 90)
    }

    @Test("Protects user source files inside Desktop")
    func protectsDesktopSourceFile() {
        let desktopSwift = URL.homeDirectory
            .appending(path: "Desktop")
            .appending(path: "Prototype.swift")
        let assessment = VitalityEngine.shared.assess(url: desktopSwift, size: 512, isDirectory: false)
        #expect(assessment.level == .vital)
    }

    @Test("Flags node_modules as safe developer artifact")
    func classifiesNodeModulesSafe() {
        let modulesURL = URL(filePath: "/tmp/app/node_modules")
        let assessment = VitalityEngine.shared.assess(url: modulesURL, size: 25_000_000, isDirectory: true)
        #expect(assessment.level == .safeToDelete)
        #expect(assessment.category == .devArtifacts)
        #expect(assessment.canBeRebuilt == true)
    }
}

@Suite("File Categorization and Sizing")
struct FileSystemUtilityTests {
    @Test("Categorizes extensions into semantic buckets")
    func categorizesExtensions() {
        #expect(FileTypeCategory.categorize(url: URL(filePath: "/tmp/spec.pdf")) == .documents)
        #expect(FileTypeCategory.categorize(url: URL(filePath: "/tmp/icon.png")) == .images)
        #expect(FileTypeCategory.categorize(url: URL(filePath: "/tmp/demo.mp4")) == .media)
        #expect(FileTypeCategory.categorize(url: URL(filePath: "/tmp/build.dmg")) == .archives)
        #expect(FileTypeCategory.categorize(url: URL(filePath: "/tmp/App.swift")) == .developer)
    }

    @Test("FileSystemSizer sums files and skips symlinks")
    func sizerSkipsSymlinks() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "crucial-sizer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let payload = Data(repeating: 0x41, count: 2048)
        let realFile = root.appending(path: "payload.bin")
        try payload.write(to: realFile)

        let symlinkURL = root.appending(path: "system-link")
        try FileManager.default.createSymbolicLink(
            at: symlinkURL,
            withDestinationURL: URL(filePath: "/System")
        )

        let measured = FileSystemSizer.size(at: root)
        #expect(measured == 2048)
    }
}

@Suite("3-Stage Duplicate Detection")
struct DuplicateDetectionTests {
    @Test("Detects identical bytes and rejects middle-byte differences")
    func detectsRealDuplicatesAndRejectsHeaderTailCollisions() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "crucial-dups-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        // > 100 KB threshold so production duplicate pipeline processes candidates end-to-end
        let dataA = Data(repeating: 0xAA, count: 120_000)
        var dataC = dataA
        dataC[60_000] = 0x55
        dataC[60_001] = 0x55

        let fileA = root.appending(path: "alpha.bin")
        let fileB = root.appending(path: "beta.bin")
        let fileC = root.appending(path: "gamma.bin")
        try dataA.write(to: fileA)
        try dataA.write(to: fileB)
        try dataC.write(to: fileC)

        let safeAssessment = VitalityAssessment.standardSafe
        let items = [
            FileItem(url: fileA, size: Int64(dataA.count), isDirectory: false, category: .duplicates, assessment: safeAssessment),
            FileItem(url: fileB, size: Int64(dataA.count), isDirectory: false, category: .duplicates, assessment: safeAssessment),
            FileItem(url: fileC, size: Int64(dataC.count), isDirectory: false, category: .duplicates, assessment: safeAssessment)
        ]

        let (groups, wasted) = DuplicateFinderService.detectDuplicates(in: items)
        #expect(groups.count == 1)
        #expect(groups.first?.duplicates.count == 1)
        #expect(wasted == Int64(dataA.count))
    }
}

@Suite("Safety Trash Guardrails and Diagnostics")
@MainActor
struct SafetyAndDiagnosticTests {
    @Test("Blocks trashing vital items and protected symlink targets")
    func blocksVitalAndSymlinkTrash() throws {
        let vitalItem = FileItem(
            url: URL(filePath: "/tmp/nonexistent-vital"),
            size: 100,
            isDirectory: false,
            category: .custom,
            assessment: .protectedSystem
        )

        #expect {
            try SafetyTrashService.shared.trash(item: vitalItem)
        } throws: { error in
            if case TrashError.protectedItem = error { return true }
            return false
        }

        let root = FileManager.default.temporaryDirectory
            .appending(path: "crucial-link-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let symlinkURL = root.appending(path: "sneaky-link")
        try FileManager.default.createSymbolicLink(
            at: symlinkURL,
            withDestinationURL: URL(filePath: "/System")
        )

        let symlinkItem = FileItem(
            url: symlinkURL,
            size: 100,
            isDirectory: false,
            category: .systemCache,
            assessment: .standardSafe
        )

        #expect {
            try SafetyTrashService.shared.trash(item: symlinkItem)
        } throws: { error in
            if case TrashError.symlinkTargetProtected = error { return true }
            return false
        }
    }

    @Test("Diagnostic engine produces clean copy without em dashes")
    func diagnosticCopyClean() async {
        let sample = FileItem(
            url: URL(filePath: "/tmp/sample-project/node_modules"),
            size: 12_000_000,
            isDirectory: true,
            category: .devArtifacts,
            assessment: .standardSafe
        )

        let profile = await FileDiagnosticEngine.shared.profile(item: sample)
        let emDash = "\u{2014}"
        #expect(!profile.functionalPurpose.contains(emDash))
        #expect(!profile.immediateImpact.contains(emDash))
        #expect(!profile.deletionVerdict.contains(emDash))
        #expect(profile.safetyConfidencePercent >= 0 && profile.safetyConfidencePercent <= 100)
    }
}
