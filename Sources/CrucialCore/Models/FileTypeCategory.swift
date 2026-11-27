import SwiftUI

public enum FileTypeCategory: String, CaseIterable, Identifiable, Sendable {
    case all = "All Files"
    case documents = "Documents & PDFs"
    case images = "Images & Photos"
    case media = "Audio & Video"
    case archives = "Archives & Packages"
    case developer = "Developer & Code"
    case system = "System & Caches"
    case other = "Other Files"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .all: "square.grid.2x2"
        case .documents: "doc.text"
        case .images: "photo"
        case .media: "film"
        case .archives: "archivebox"
        case .developer: "chevron.left.forwardslash.chevron.right"
        case .system: "gearshape"
        case .other: "doc"
        }
    }

    public var color: Color {
        switch self {
        case .all: CrucialTheme.accentInk
        case .documents: CrucialTheme.cobalt
        case .images: CrucialTheme.glacierCyan
        case .media: CrucialTheme.starOchre
        case .archives: CrucialTheme.warning
        case .developer: CrucialTheme.accentInk
        case .system: CrucialTheme.slateBlue
        case .other: CrucialTheme.textSecondary
        }
    }

    public static func categorize(url: URL) -> FileTypeCategory {
        let ext = url.pathExtension.lowercased()
        let path = url.path.lowercased()

        let docExts: Set<String> = [
            "pdf", "doc", "docx", "txt", "rtf", "pages", "md", "markdown",
            "csv", "xlsx", "xls", "numbers", "ppt", "pptx", "key", "keynote", "epub", "odt"
        ]
        if docExts.contains(ext) {
            return .documents
        }

        let imageExts: Set<String> = [
            "jpg", "jpeg", "png", "gif", "webp", "svg", "heic", "heif",
            "tiff", "tif", "bmp", "psd", "ai", "raw", "cr2", "nef", "ico"
        ]
        if imageExts.contains(ext) {
            return .images
        }

        let mediaExts: Set<String> = [
            "mp4", "mov", "mkv", "avi", "webm", "m4v", "wmv", "flv",
            "mp3", "wav", "m4a", "flac", "aac", "ogg", "wma", "aiff"
        ]
        if mediaExts.contains(ext) {
            return .media
        }

        let archiveExts: Set<String> = [
            "zip", "dmg", "pkg", "tar", "gz", "tgz", "7z", "rar", "iso", "bz2", "xz", "zst"
        ]
        if archiveExts.contains(ext) {
            return .archives
        }

        let devExts: Set<String> = [
            "swift", "py", "ts", "js", "tsx", "jsx", "c", "cpp", "h", "hpp",
            "m", "mm", "rs", "go", "java", "kt", "rb", "php", "sh", "bash", "zsh",
            "html", "css", "scss", "json", "yaml", "yml", "xml", "toml", "sql", "graphql", "proto"
        ]
        if devExts.contains(ext)
            || path.contains("deriveddata")
            || path.contains("node_modules")
            || path.contains(".build") {
            return .developer
        }

        let systemExts: Set<String> = ["cache", "log", "diag", "crash", "plist", "dylib", "kext", "framework"]
        if path.hasPrefix("/system")
            || path.hasPrefix("/library")
            || path.contains("/caches/")
            || systemExts.contains(ext) {
            return .system
        }

        return .other
    }

    public static func formatDescription(for extensionName: String) -> String {
        let ext = extensionName.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        switch ext {
        case "pdf": return "Portable Document Format (PDF)"
        case "docx", "doc": return "Microsoft Word Document"
        case "xlsx", "xls": return "Microsoft Excel Spreadsheet"
        case "pptx", "ppt": return "Microsoft PowerPoint Presentation"
        case "pages": return "Apple Pages Document"
        case "key", "keynote": return "Apple Keynote Presentation"
        case "numbers": return "Apple Numbers Spreadsheet"
        case "txt": return "Plain Text Document"
        case "rtf": return "Rich Text Format Document"
        case "md", "markdown": return "Markdown Document"
        case "csv": return "Comma Separated Values Data"
        case "jpg", "jpeg": return "JPEG Photographic Image"
        case "png": return "Portable Network Graphics Image"
        case "webp": return "WebP Compressed Image"
        case "heic", "heif": return "Apple High Efficiency Image Container"
        case "gif": return "Graphics Interchange Format Image"
        case "svg": return "Scalable Vector Graphic"
        case "psd": return "Adobe Photoshop Document"
        case "ai": return "Adobe Illustrator Artwork"
        case "mp4": return "MPEG-4 Video"
        case "mov": return "Apple QuickTime Movie"
        case "mkv": return "Matroska Multimedia Container"
        case "mp3": return "MPEG-3 Audio File"
        case "m4a": return "Apple AAC / Lossless Audio"
        case "wav": return "Waveform Uncompressed Audio"
        case "zip": return "Compressed ZIP Archive"
        case "dmg": return "Apple Disk Image Installer"
        case "pkg": return "macOS Installer Package"
        case "tar", "gz": return "Gzip Compressed Tarball"
        case "swift": return "Swift Source Code"
        case "py": return "Python Script"
        case "ts", "tsx": return "TypeScript Source Code"
        case "js", "jsx": return "JavaScript Source Code"
        case "json": return "JSON Data"
        default: return ext.isEmpty ? "File" : ".\(ext.uppercased()) File"
        }
    }
}
