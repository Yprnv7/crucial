import Foundation
import AppKit

@MainActor
public final class SystemFileSearchService: ObservableObject {
    public static let shared = SystemFileSearchService()

    @Published public var isSearching: Bool = false
    @Published public var searchResults: [FileItem] = []
    @Published public var lastQuery: String = ""

    private init() {}

    /// Performs a high-speed system-wide search across the Mac using native macOS Spotlight (mdfind)
    /// with direct filesystem fallback and intelligent relevance ranking.
    public func search(query: String, maxResults: Int = 300) async -> [FileItem] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else {
            self.searchResults = []
            self.lastQuery = ""
            self.isSearching = false
            return []
        }

        self.isSearching = true
        self.lastQuery = cleanQuery

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        let results = await Task.detached(priority: .userInitiated) { () -> [FileItem] in
            var matchedPaths: [String] = []
            var seenPaths: Set<String> = []

            // 1. Prioritized Direct Crawl of Primary User Directories first (instant user files)
            let home = FileManager.default.homeDirectoryForCurrentUser
            let targetDirs = [
                home.appendingPathComponent("Desktop"),
                home.appendingPathComponent("Documents"),
                home.appendingPathComponent("Downloads"),
                home.appendingPathComponent("Movies"),
                home.appendingPathComponent("Music"),
                home.appendingPathComponent("Pictures")
            ]

            let lowerQ = cleanQuery.lowercased()
            for dir in targetDirs {
                guard let contents = try? FileManager.default.contentsOfDirectory(
                    at: dir,
                    includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }

                for fileURL in contents {
                    let filename = fileURL.lastPathComponent.lowercased()
                    if filename.contains(lowerQ) {
                        if !seenPaths.contains(fileURL.path) {
                            seenPaths.insert(fileURL.path)
                            matchedPaths.append(fileURL.path)
                        }
                    }
                }
            }

            // 2. Run mdfind for Spotlight matches across the entire Mac
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
            process.arguments = ["-name", cleanQuery]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: .newlines)
                    for line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty, !seenPaths.contains(trimmed) else { continue }
                        seenPaths.insert(trimmed)
                        matchedPaths.append(trimmed)
                        if matchedPaths.count >= maxResults { break }
                    }
                }
            } catch {
                // Spotlight fallback
            }

            // 3. Convert matched paths to rich FileItem models with vitality assessment
            var items: [FileItem] = []
            let fm = FileManager.default

            for path in matchedPaths {
                let url = URL(fileURLWithPath: path)
                guard fm.fileExists(atPath: path) else { continue }

                var isDir: ObjCBool = false
                fm.fileExists(atPath: path, isDirectory: &isDir)

                let size: Int64
                if isDir.boolValue {
                    size = calculateFastDirectorySize(at: url)
                } else {
                    let attrs = try? fm.attributesOfItem(atPath: path)
                    size = (attrs?[.size] as? Int64) ?? 0
                }

                let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                let category = categorizeFile(url: url)
                let assessment = VitalityEngine.shared.assess(url: url, size: size, isDirectory: isDir.boolValue)

                let item = FileItem(
                    url: url,
                    name: url.lastPathComponent,
                    size: size,
                    isDirectory: isDir.boolValue,
                    modificationDate: modDate,
                    category: category,
                    assessment: assessment,
                    isSelected: false
                )
                items.append(item)
            }

            // 4. Intelligent Relevance Sorting:
            // - User workspace files (Desktop, Documents, Downloads) ranked HIGHEST
            // - Standalone keyword/token matches ranked over accidental substring in system files
            // - System / Library files placed at bottom
            return items.sorted { a, b in
                let scoreA = computeRelevanceScore(item: a, query: lowerQ, homeDir: homeDir)
                let scoreB = computeRelevanceScore(item: b, query: lowerQ, homeDir: homeDir)
                if scoreA != scoreB {
                    return scoreA > scoreB
                }
                return a.size > b.size
            }
        }.value

        self.searchResults = results
        self.isSearching = false
        return results
    }

    /// Fast categorized search for specific intent (e.g. CV, Resume, Videos, Documents)
    public func findFiles(matchingKeywords keywords: [String], maxResults: Int = 100) async -> [FileItem] {
        var allFound: [FileItem] = []
        var seenPaths: Set<String> = []

        for kw in keywords {
            let items = await self.search(query: kw, maxResults: maxResults)
            for item in items {
                if !seenPaths.contains(item.path) {
                    seenPaths.insert(item.path)
                    allFound.append(item)
                }
            }
        }

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return allFound.sorted { a, b in
            let scoreA = computeRelevanceScore(item: a, query: keywords.first?.lowercased() ?? "", homeDir: homeDir)
            let scoreB = computeRelevanceScore(item: b, query: keywords.first?.lowercased() ?? "", homeDir: homeDir)
            if scoreA != scoreB {
                return scoreA > scoreB
            }
            return a.size > b.size
        }
    }
}

// MARK: - Non-isolated Search Utilities
private func computeRelevanceScore(item: FileItem, query: String, homeDir: String) -> Int {
    var score = 0
    let path = item.path.lowercased()
    let name = item.name.lowercased()

    // 1. User Directory Priority (+10,000 for top user folders)
    if path.hasPrefix(homeDir + "/desktop") || path.hasPrefix(homeDir + "/documents") || path.hasPrefix(homeDir + "/downloads") {
        score += 10000
    } else if path.hasPrefix(homeDir) {
        score += 5000
    }

    // 2. Penalty for internal System and Library paths
    if path.hasPrefix("/system") || path.hasPrefix("/library") || path.hasPrefix("/private") || path.hasPrefix("/usr") {
        score -= 8000
    }

    // 3. Exact word boundary / token match (e.g. "cv" surrounded by spaces, dashes, or dots)
    let tokenMatches = ["_\(query).", "-\(query).", " \(query).", "_\(query)_", "-\(query)-", " \(query) "]
    for token in tokenMatches {
        if name.contains(token) {
            score += 4000
            break
        }
    }

    if name.starts(with: query) {
        score += 2000
    }

    // 4. File Type Boost (documents, pdfs, images vs framework binaries)
    switch item.fileTypeCategory {
    case .documents:
        score += 1500
    case .images, .media:
        score += 1000
    case .archives:
        score += 800
    case .developer:
        score += 500
    case .system, .other:
        break
    case .all:
        break
    }

    // 5. Recency
    if let mod = item.modificationDate {
        let daysAgo = Calendar.current.dateComponents([.day], from: mod, to: Date()).day ?? 1000
        if daysAgo < 30 {
            score += 500
        }
    }

    return score
}

private func categorizeFile(url: URL) -> JunkCategory {
    let path = url.path.lowercased()
    let ext = url.pathExtension.lowercased()

    if path.contains("deriveddata") || path.contains("node_modules") || path.contains(".build") || ext == "o" {
        return .devArtifacts
    }
    if path.contains("/caches/") || ext == "cache" || ext == "tmp" {
        return .systemCache
    }
    if path.contains("/logs/") || ext == "log" || ext == "diag" {
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

private func calculateFastDirectorySize(at url: URL) -> Int64 {
    var total: Int64 = 0
    guard let contents = try? FileManager.default.contentsOfDirectory(
        at: url,
        includingPropertiesForKeys: [.fileSizeKey],
        options: [.skipsHiddenFiles]
    ) else {
        return 0
    }
    for fileURL in contents.prefix(150) {
        if let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
            total += Int64(size)
        }
    }
    return total
}
