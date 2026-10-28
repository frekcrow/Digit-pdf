# TrollDocs (iOS 15.0+)

**TrollDocs** is a native iOS document creator and utility tailored specifically for **TrollStore** users on iOS 15.0+. It enables users to create, preview, manage, and export various document formats directly on-device without Apple Developer Certificate requirements, revokes, or 7-day expiration limitations.

---

## Features

- **Document Formats Supported:**
  - **PDF (`.pdf`):** Multi-page document compilation using `UIGraphicsPDFRenderer` and CoreText with automatic text pagination, document banners, running headers, and page numbering.
  - **Plain Text (`.txt`):** Fast UTF-8 text file generation with formatted document header stamps.
  - **CSV (`.csv`):** Standard RFC 4180 spreadsheet generation with delimiter auto-detection and quote escaping.
  - **OpenXML (`.docx`, `.xlsx`, `.pptx`):** Extensible architecture via `OpenXMLGeneratable` protocol ready for Phase 2 packaging.
- **Native QuickLook Preview:** Instant previewing of generated documents using iOS `QLPreviewController` wrapped seamlessly in SwiftUI.
- **Full File Sharing & Files App Integration:** Configured with `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`. All generated documents appear automatically inside the iOS **Files** app under `On My iPhone/iPad -> TrollDocs`.
- **System Share Sheet:** Quick export via AirDrop, Mail, Messages, or any installed app using native `UIActivityViewController`.
- **TrollStore Entitlements:** Includes preconfigured entitlements with an unsandboxed access toggle (`com.apple.private.security.no-sandbox`).

---

## Project Structure

```
TrollDocs/
├── .github/
│   └── workflows/
│       └── build.yml               # GitHub Actions CI/CD (XcodeGen, xcodebuild, ldid, TIPA packaging)
├── project.yml                     # XcodeGen project specification
├── Resources/
│   ├── Info.plist                  # Configured with UIFileSharingEnabled & document handling
│   ├── TrollDocs.entitlements      # TrollStore privileges (sandboxed by default, toggleable)
│   └── Assets.xcassets/            # App icons and color schemes
└── Sources/
    ├── TrollDocsApp.swift          # Main SwiftUI app lifecycle entry point
    ├── Models/
    │   ├── DocumentFormat.swift    # Supported formats, metadata, system icons, and colors
    │   └── DocumentItem.swift      # Model for generated files on disk
    ├── Services/
    │   ├── DocumentGeneratorService.swift  # PDF, TXT, CSV rendering & OpenXML protocol scaffolding
    │   └── FileManagerService.swift        # File system persistence in app's Documents folder
    ├── ViewModels/
    │   ├── DashboardViewModel.swift        # State management, search, and format filtering
    └── Views/
        ├── DashboardView.swift             # Main document dashboard, filter bar, search, and list
        ├── DocumentRowView.swift           # Individual document item row component
        ├── CreateDocumentView.swift        # Interactive form with templates & format selector
        ├── QuickLookPreviewView.swift      # QLPreviewController wrapper for SwiftUI
        └── ShareSheetView.swift            # UIActivityViewController wrapper for SwiftUI
```

---

## TrollStore Entitlements & Sandboxing

TrollDocs is preconfigured with `Resources/TrollDocs.entitlements`:

```xml
<dict>
    <!-- Set to 'false' (default): Runs in container with native iOS Files app integration.
         Set to 'true': Bypasses sandbox with full root filesystem privileges. -->
    <key>com.apple.private.security.no-sandbox</key>
    <false/>

    <key>com.apple.private.security.storage.AppDataContainers</key>
    <true/>
</dict>
```

- **Container Mode (`false`):** Safe, standard sandbox mode where all created files are stored in `Documents/` and can be browsed, copied, and opened using the iOS Files app.
- **Root Mode (`true`):** Allows TrollDocs to access paths outside the sandbox (such as `/var/mobile` or root filesystem) if needed in future phases.

---

## Automated CI/CD & Build Workflow

Since development can be done entirely without a local Mac/Xcode setup, the project utilizes **XcodeGen** and **GitHub Actions**:

1. **Trigger:** Push to `main` branch or manual `workflow_dispatch`.
2. **Environment:** macOS runner (`macos-latest`).
3. **Tool Installation:** Installs `xcodegen` and `ldid` via Homebrew.
4. **Project Generation:** `xcodegen generate` generates `TrollDocs.xcodeproj` from `project.yml`.
5. **Compilation:** Compiles for generic iOS device (`generic/platform=iOS`) in `Release` configuration with code signing disabled.
6. **Fake-Signing:** Injects TrollStore entitlements into the Mach-O binary using `ldid -SResources/TrollDocs.entitlements`.
7. **Packaging:** Bundles the app into `Payload/` and creates both `.ipa` and `.tipa`.
8. **Artifact Delivery:** Uploads the builds directly to the GitHub Actions Run summary.

---

## Installation via TrollStore

1. Go to the **Actions** tab in your GitHub repository.
2. Select the latest successful build and download the `TrollDocs-TrollStore` artifact.
3. Extract the artifact to obtain `TrollDocs.ipa` (or `TrollDocs.tipa`).
4. Transfer the file to your iOS device (via AirDrop, iCloud Drive, or local browser).
5. Open the file with **TrollStore** and tap **Install**.
