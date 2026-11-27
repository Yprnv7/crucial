import Foundation
import Observation

@Observable
@MainActor
public final class SystemFileSearchService {
    public static let shared = SystemFileSearchService()

    public var isSearching: Bool = false
    public var searchResults: [FileItem] = []
    public var lastQuery: String = ""

    private init() {}

    public func search(query: String, maxResults: Int = 300) async -> [FileItem] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else {
            searchResults = []
            lastQuery = ""
            isSearching = false
            return []
        }

        isSearching = true
        lastQuery = cleanQuery

        let home = URL.homeDirectory
        let mdfindOutput = await SubprocessRunner.run(executable: "/usr/bin/mdfind", arguments: ["-name", cleanQuery])

        let results = await Task.detached(priority: .userInitiated) { () -> [FileItem] in
            Self.processMatches(cleanQuery: cleanQuery, mdfindOutput: mdfindOutput, home: home, maxResults: maxResults)
        }.value

        searchResults = results
        isSearching = false
        return results
    }

    public func findFiles(matchingKeywords keywords: [String], maxResults: Int = 100) async -> [FileItem] {
        var allFound: [FileItem] = []
        var seenPaths: Set<String> = []

        for kw in keywords {
            let items = await search(query: kw, maxResults: maxResults)
            for item in items where !seenPaths.contains(item.path) {
                seenPaths.insert(item.path)
                allFound.append(item)
            }
        }

        let primaryQuery = keywords.first?.lowercased() ?? ""
        let homeDir = URL.homeDirectory.path
        return allFound.sorted { a, b in
            let scoreA = Self.computeRelevanceScore(item: a, query: primaryQuery, homeDir: homeDir)
            let scoreB = Self.computeRelevanceScore(item: b, query: primaryQuery, homeDir: homeDir)
            if scoreA != scoreB { return scoreA > scoreB }
            return a.size > b.size
        }
    }

    private nonisolated static func processMatches(
        cleanQuery: String,
        mdfindOutput: String,
        home: URL,
        maxResults: Int
    ) -> [FileItem] {
        var matchedPaths: [String] = []
        var seenPaths: Set<String> = []
        let homeDir = home.path

        let targetDirs = [
            home.appending(path: "Desktop"),
            home.appending(path: "Documents"),
            home.appending(path: "Downloads"),
            home.appending(path: "Movies"),
            home.appending(path: "Music"),
            home.appending(path: "Pictures")
        ]

        for dir in targetDirs {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for fileURL in contents {
                if fileURL.lastPathComponent.localizedStandardContains(cleanQuery),
                   !seenPaths.contains(fileURL.path) {
                    seenPaths.insert(fileURL.path)
                    matchedPaths.append(fileURL.path)
                }
            }
        }

        for line in mdfindOutput.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seenPaths.contains(trimmed) else { continue }
            seenPaths.insert(trimmed)
            matchedPaths.append(trimmed)
            if matchedPaths.count >= maxResults { break }
        }

        var items: [FileItem] = []
        let fm = FileManager.default
        for path in matchedPaths {
            let url = URL(fileURLWithPath: path)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: path, isDirectory: &isDir) else { continue }

            let size = isDir.boolValue ? fastShallowDirectorySize(at: url) : FileSystemSizer.size(at: url)
            let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            let category = categorizeFile(url: url)
            let assessment = VitalityEngine.shared.assess(url: url, size: size, isDirectory: isDir.boolValue)

            items.append(FileItem(
                url: url,
                name: url.lastPathComponent,
                size: size,
                isDirectory: isDir.boolValue,
                modificationDate: modDate,
                category: category,
                assessment: assessment,
                isSelected: false
            ))
        }

        let lowerQ = cleanQuery.lowercased()
        return items.sorted { a, b in
            let scoreA = computeRelevanceScore(item: a, query: lowerQ, homeDir: homeDir)
            let scoreB = computeRelevanceScore(item: b, query: lowerQ, homeDir: homeDir)
            if scoreA != scoreB { return scoreA > scoreB }
            return a.size > b.size
        }
    }

    private nonisolated static func computeRelevanceScore(item: FileItem, query: String, homeDir: String) -> Int {
        var score = 0
        let path = item.path.lowercased()
        let name = item.name.lowercased()
        let lowerHome = homeDir.lowercased()

        if path.hasPrefix(lowerHome + "/desktop") || path.hasPrefix(lowerHome + "/documents") || path.hasPrefix(lowerHome + "/downloads") {
            score += 10_000
        } else if path.hasPrefix(lowerHome) {
            score += 5_000
        }

        if path.hasPrefix("/system") || path.hasPrefix("/library") || path.hasPrefix("/private") || path.hasPrefix("/usr") {
            score -= 8_000
        }

        let tokenMatches = ["_\(query).", "-\(query).", " \(query).", "_\(query)_", "-\(query)-", " \(query) "]
        if tokenMatches.contains(where: { name.contains($0) }) {
            score += 4_000
        }
        if name.starts(with: query) {
            score += 2_000
        }

        switch item.fileTypeCategory {
        case .documents: score += 1_500
        case .images, .media: score += 1_000
        case .archives: score += 800
        case .developer: score += 500
        case .system, .other, .all: break
        }

        if item.daysSinceLastAccess < 30 {
            score += 500
        }
        return score
    }

    private nonisolated static func categorizeFile(url: URL) -> JunkCategory {
        let path = url.path.lowercased()
        let ext = url.pathExtension.lowercased()

        if path.contains("deriveddata") || path.contains("node_modules") || path.contains(".build") || ext == "o" {
            return .devArtifacts
        }
        if path.contains("/caches/") || path.contains("/logs/") || ["cache", "tmp", "log", "diag"].contains(ext) {
            return .systemCache
        }
        if path.contains("/downloads/") || ["zip", "dmg", "pkg", "iso", "tar", "gz"].contains(ext) {
            return .largeUnused
        }
        if path.contains("/application support/") {
            return .appResidue
        }
        return .custom
    }

    private nonisolated static func fastShallowDirectorySize(at url: URL) -> Int64 {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        return contents.prefix(150).reduce(0) { partial, fileURL in
            let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey])
            if values?.isSymbolicLink == true { return partial }
            return partial + Int64(values?.fileSize ?? 0)
        }
    }
}
