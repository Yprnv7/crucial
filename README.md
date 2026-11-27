# Crucial

Open-source native macOS storage analyzer, developer artifact cleaner, and application uninstaller built with Swift 6 and SwiftUI.

- **Website:** [https://yprnv7.github.io/crucial/](https://yprnv7.github.io/crucial/)
- **Download (Apple Silicon):** [Crucial-1.0.0-arm64.dmg](https://github.com/Yprnv7/crucial/releases/download/v1.0.0/Crucial-1.0.0-arm64.dmg)
- **Repository:** [https://github.com/Yprnv7/crucial](https://github.com/Yprnv7/crucial)

## Architecture

Crucial is split into a testable core library and a macOS application target:

- `Sources/CrucialCore/Models/`: Palette (`CrucialTheme`, `CrucialSpacing`, `CrucialMotion`), volume telemetry models, duplicate groups, and application metadata.
- `Sources/CrucialCore/Services/`: Symlink-safe `FileSystemSizer`, `VitalityEngine`, Trash-only `SafetyTrashService`, 3-stage `DuplicateFinderService`, `AppUninstallerService`, `FileDiagnosticEngine`, and optional offline `LocalLLMService`.
- `Sources/CrucialCore/Views/`: `NavigationSplitView` desktop workspace, forensic inspector, Swift Charts volume breakdown, settings (`Cmd-,`), and `MenuBarExtra` monitor.
- `Sources/CrucialApp/`: `@main` entry point, command shortcuts (`Cmd+1` through `Cmd+8`, `Cmd+R`), and scene configuration.
- `Tests/CrucialTests/`: Automated safety, symlink, deduplication, and categorization test suite.

## Safety Model

1. **Trash-First Only:** Every cleanup action routes through `FileManager.trashItem` (or `NSWorkspace.shared.recycle`) instead of irreversible unlinks.
2. **Symlink Guardrails:** Directory enumeration skips symbolic links so external or OS targets never inflate byte totals, and `SafetyTrashService` resolves symlink targets prior to Trash staging.
3. **3-Stage Duplicate Hashing:** Files match only after identical byte length, identical 4 KB header and tail digests, and full CryptoKit SHA-256 confirmation.
4. **Offline Operation:** Zero network API calls, telemetry, or analytics. Diagnostic rules run locally, with optional offline `llama.cpp` inference discovered dynamically in `Bundle.main` or `Application Support/Crucial/`.

## Requirements & Building from Source

- **macOS:** 14.0 (Sonoma) or newer
- **Architecture:** Prebuilt DMG targets Apple Silicon (`arm64`); source builds support both Apple Silicon and Intel via SwiftPM
- **Toolchain:** Swift 6.0+

```bash
# Compile debug binary (CrucialCore + Crucial executable)
swift build

# Build 3.7 MB release binary and package build/Crucial.app
./scripts/build_app.sh

# Package Apple Silicon DMG into dist/
./scripts/package_dmg.sh
```

## License

MIT License
