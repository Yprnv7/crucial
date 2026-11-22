# Crucial ⚡🛡️
### Native macOS Menu Bar Junk Cleaner & Intelligent File Finder

**Crucial** is a high-performance, native macOS menu bar utility designed to help you find files across your Mac and determine with certainty whether a file is **vital** to your system/projects or **safe to delete**.

Built with **Swift & SwiftUI**, Crucial lives exclusively in your macOS menu bar without dock clutter, providing an action-first quick cleaner and a pop-out deep File Finder & Vitality Inspector.

---

## 🌟 Key Features

### 1. ⚡ Action-First Menu Bar Dashboard
- Lives in your macOS menu bar (`NSStatusItem` / `MenuBarExtra`).
- Real-time disk space gauge showing Macintosh HD capacity, used percentage, and total cleanable space.
- Quick clean categories:
  - 🛠️ **Developer Caches**: `node_modules`, Xcode `DerivedData`, Rust `target/`, Python `.venv`, `__pycache__`, build artifacts.
  - ⚙️ **System & User Caches**: `~/Library/Caches`, browser caches, diagnostic crash logs.
  - 🗑️ **Orphaned App Residue**: Leftover folders in `~/Library/Application Support/` from uninstalled apps.
  - 📦 **Large Idle Files**: DMGs, PKGs, ISOs, and archives older than 30–60 days.
- **1-Click Safe Cleanup**: Safely moves cleanable items to the macOS Trash with zero risk to system or personal files.

### 2. 🔍 Pop-out File Finder & Vitality Inspector
- Search across your disk by filename, path, extension, or natural language query.
- Instant category filter chips (`[All]`, `[Developer Caches]`, `[System Caches]`, `[Large Files]`, `[Orphaned Residue]`).
- Side-by-side inspection layout:
  - **Left Pane**: Filtered file list sorted by size, displaying file icons, paths, and color-coded Vitality Badges (`🟢 Safe`, `🟡 Caution`, `🛑 Protected`).
  - **Right Pane (Crucial Vitality Card)**:
    - **Risk Score Gauge** (0–100 risk score).
    - **Contextual Summary**: What created this file and why it is here.
    - **Impact Analysis**: What happens if you delete it.
    - **Rebuild Command**: Shows the exact command to regenerate the artifact (e.g., `npm install`, `cargo build`).
    - **Quick Actions**: Move to Trash, Reveal in Finder, and Copy Rebuild Command.

### 3. 🧠 Hybrid Vitality Engine (Local Rules + Gemini AI)
- **Local Rule Engine**: Deterministic classification based on SIP paths, active app bundles, git repositories, personal documents, and known cache signatures.
- **Automatic Gemini AI Explanation**: Connects with Google's Gemini API (`gemini-2.5-flash`) to automatically analyze unknown files and scripts as you browse them, explaining their creator, purpose, and deletion safety.

### 4. 🛡️ Crucial Safety Lock & Trash Protocol
- **Safety Lock**: Files marked as `🛑 Protected / Vital` (system files, personal source code, git histories) are physically locked from deletion.
- **Native macOS Trash**: Cleaned files are moved to the macOS Trash (`FileManager.default.trashItem`) rather than permanently purged, ensuring every action is undoable.

---

## 🚀 Installation & Running

### Option 1: Run the Pre-Packaged App
The release bundle is generated inside `build/Crucial.app`:

```bash
# Open directly:
open build/Crucial.app

# Or install to your Mac's Applications folder:
cp -r build/Crucial.app /Applications/
```

### Option 2: Run via Swift Package Manager
```bash
cd /Users/py/.gemini/antigravity/scratch/crucial
swift run
```

### Option 3: Rebuild the Release App Bundle
```bash
./scripts/build_app.sh
```

---

## ⚙️ Configuration & Permissions

1. **Full Disk Access (Recommended)**:
   - For Crucial to clean deep system caches and Xcode DerivedData, grant Full Disk Access in **System Settings** > **Privacy & Security** > **Full Disk Access**.
   - You can also click the prompt button directly inside Crucial's Settings panel (`⚙️`).
2. **AI Reasoning Key (Optional)**:
   - To enable deep AI contextual file analysis, enter your Gemini API key in Crucial's Settings (`⚙️`) or set the `GEMINI_API_KEY` environment variable.

---

## 🛠️ Project Structure

```
crucial/
├── Package.swift                    # Swift Package Manager configuration
├── scripts/
│   └── build_app.sh                 # Builds and packages standalone Crucial.app
├── Sources/
│   └── Crucial/
│       ├── App/
│       │   ├── CrucialApp.swift     # SwiftUI MenuBarExtra app entry point
│       │   └── WindowManager.swift  # Floating Finder & Settings window manager
│       ├── Models/
│       │   ├── FileItem.swift       # File item model with icon & formatted size
│       │   └── VitalityStatus.swift # Vitality levels, categories, and risk scores
│       ├── Services/
│       │   ├── FileScannerService.swift       # High-speed disk & cache crawler
│       │   ├── VitalityEngine.swift           # Rule-based safety & risk classifier
│       │   ├── GeminiExplainerService.swift   # AI contextual analyzer via Gemini API
│       │   ├── SafetyTrashService.swift       # Safe macOS Trash & undo manager
│       │   └── PermissionsService.swift       # Full Disk Access & security checker
│       └── Views/
│           ├── MenuBarView.swift    # Compact Menu Bar Quick Clean dashboard
│           ├── FileFinderView.swift # Pop-out Finder & Vitality Inspector
│           └── SettingsView.swift   # Permissions & Gemini API settings
└── README.md
```

---

## 📄 License
MIT
