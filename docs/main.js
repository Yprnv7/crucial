document.addEventListener("DOMContentLoaded", () => {
    initNavigationDrawer();
    initWorkspaceTabs();
    initShowcaseVideo();
});

function initNavigationDrawer() {
    const toggle = document.getElementById("menu-toggle");
    const drawer = document.getElementById("mobile-drawer");
    if (!toggle || !drawer) return;

    const setOpen = (open) => {
        drawer.setAttribute("data-open", open ? "true" : "false");
        toggle.setAttribute("aria-expanded", open ? "true" : "false");
        toggle.textContent = open ? "Close" : "Menu";
    };

    toggle.addEventListener("click", () => {
        const isOpen = drawer.getAttribute("data-open") === "true";
        setOpen(!isOpen);
    });

    drawer.querySelectorAll("a").forEach((link) => {
        link.addEventListener("click", () => setOpen(false));
    });

    document.addEventListener("keydown", (event) => {
        if (event.key === "Escape" && drawer.getAttribute("data-open") === "true") {
            setOpen(false);
            toggle.focus();
        }
    });
}

function initWorkspaceTabs() {
    const tabButtons = Array.from(document.querySelectorAll("[data-workspace-tab]"));
    const previewImg = document.getElementById("workspace-preview-image");
    const previewTitle = document.getElementById("workspace-preview-title");
    const previewDesc = document.getElementById("workspace-preview-desc");
    const previewChecks = document.getElementById("workspace-preview-checks");

    if (!tabButtons.length || !previewImg || !previewTitle || !previewDesc || !previewChecks) {
        return;
    }

    const workspaces = {
        dashboard: {
            image: "screens/dashboard.png",
            alt: "Crucial Clean Dashboard summarizing reclaimable storage categories and live volume capacity",
            title: "Clean Dashboard",
            desc: "Computes live APFS volume telemetry via diskutil and measures Developer Caches, System & User Caches, Orphaned App Residue, and Large Unused Files without blocking the UI thread.",
            checks: [
                "Live free, total, and reclaimable capacity ring",
                "Explicit confirmation before staging items to Trash",
                "Symlink-safe enumeration skipping external mount targets"
            ]
        },
        uninstaller: {
            image: "screens/uninstaller.png",
            alt: "Crucial App Uninstaller showing application bundle footprint and correlated Library support files",
            title: "App Uninstaller",
            desc: "Matches bundles in /Applications against ~/Library support directories, caches, saved states, logs, and sandboxes so every component can be reviewed prior to Trash removal.",
            checks: [
                "Supports dragging custom .app bundles directly onto the window",
                "Graceful NSRunningApplication termination with polling timeout",
                "Protects core macOS system applications from accidental selection"
            ]
        },
        treemap: {
            image: "screens/treemap.png",
            alt: "Crucial Storage Breakdown chart showing APFS allocation across applications, media, and caches",
            title: "Storage Breakdown",
            desc: "Visualizes whole-volume allocation alongside cleanable sector proportions using Swift Charts and live filesystem measurements.",
            checks: [
                "Measured /Applications, home media, developer cache, and free totals",
                "Toggle between Volume Capacity and Cleanable Sectors",
                "Direct sector navigation into category inspection views"
            ]
        },
        maintenance: {
            image: "screens/maintenance.png",
            alt: "Crucial System Maintenance tasks including DNS cache flush, Spotlight indexing, and Time Machine snapshot thinning",
            title: "System Maintenance",
            desc: "Wraps documented macOS system tools (tmutil, dscacheutil, purge, mdutil) through an asynchronous subprocess runner with status logging per task.",
            checks: [
                "Thin local Time Machine APFS snapshots cleanly",
                "Flush macOS DNS resolver and mDNSResponder caches",
                "Surfaces command output directly inside each task row"
            ]
        },
        assistant: {
            image: "screens/assistant.png",
            alt: "Crucial Assistant analyzing local file safety and rebuildability offline",
            title: "Local Crucial Assistant",
            desc: "Combines the deterministic VitalityEngine safety rules with optional on-device Llama 3.2 1B Q4 inference to answer file questions completely offline.",
            checks: [
                "Dynamic discovery of llama-cli and GGUF weights with deterministic fallback",
                "Shows matching local files and executable actions in-thread",
                "Zero outbound telemetry or external network API keys"
            ]
        }
    };

    const selectWorkspace = (key) => {
        const spec = workspaces[key];
        if (!spec) return;

        tabButtons.forEach((btn) => {
            const active = btn.getAttribute("data-workspace-tab") === key;
            btn.setAttribute("aria-selected", active ? "true" : "false");
        });

        previewImg.src = spec.image;
        previewImg.alt = spec.alt;
        previewTitle.textContent = spec.title;
        previewDesc.textContent = spec.desc;
        previewChecks.replaceChildren(
            ...spec.checks.map((item) => {
                const li = document.createElement("li");
                li.textContent = item;
                return li;
            })
        );
    };

    tabButtons.forEach((btn) => {
        btn.addEventListener("click", () => {
            selectWorkspace(btn.getAttribute("data-workspace-tab"));
        });
    });

    selectWorkspace("dashboard");
}

function initShowcaseVideo() {
    const video = document.getElementById("showcase-video");
    const toggleBtn = document.getElementById("video-toggle-btn");
    if (!video || !toggleBtn) return;

    const syncLabel = () => {
        toggleBtn.textContent = video.paused ? "Play Walkthrough" : "Pause Walkthrough";
    };

    toggleBtn.addEventListener("click", () => {
        if (video.paused) {
            video.play().catch(() => {});
        } else {
            video.pause();
        }
        syncLabel();
    });

    video.addEventListener("play", syncLabel);
    video.addEventListener("pause", syncLabel);
    syncLabel();
}
