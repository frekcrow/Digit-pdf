# TrollDocs (iOS 15.0+)

**TrollDocs** is a desktop-class native iOS **PDF Creator, Typesetter, and Studio** designed specifically for **TrollStore** users on iOS 15.0+.

Rather than treating PDFs as uneditable static exports, TrollDocs gives you **full creative and editorial control** over your PDF documents: from typesetting rich multi-page manuscripts with professional desktop typography and page geometry to in-document full-text search, live PDFKit rendering, and direct integration with the iOS Files app.

---

## Core Capabilities (Exclusively PDF)

### 1. High-Fidelity Typesetting & Editor
- **Rich Typography Canvas:** Write manuscripts with paragraph hierarchies (Title, Heading 1, Heading 2, Heading 3, Body copy, Blockquotes).
- **Inline Styling:** **Bold**, *Italic*, <u>Underline</u>, and paragraph alignments (Left, Justified, Center).
- **Desktop Page Geometry & Setup:**
  - Standard paper formats: **A4**, **US Letter**, **Legal**, and **A5**.
  - Orientation: **Portrait** or **Landscape**.
  - Margin presets: **Narrow**, **Normal**, **Wide**, and **Custom**.
  - Folios & Headers: Running top headers, rule lines, and page numbers.
- **CoreText Pagination Engine:** Paginated output measured and broken mathematically across pages—never a screenshot or web view snapshot.

### 2. TrollPDF Studio & Reader (`PDFKit`)
- **Native PDFKit Integration:** Smooth hardware-accelerated viewing with pinch-to-zoom.
- **In-Document Full-Text Search:** Find words and phrases with match highlighting and step-through navigation.
- **Page Scrubber:** Rapid jumping between pages (`Page 3 of 12`).
- **Instant Print Preview:** Switch between the manuscript desk and print-ready proof.

### 3. PDF File Management & External Import
- **Import Existing PDFs:** Integrated `UIDocumentPickerViewController` allows importing any `.pdf` document from iOS Files, iCloud Drive, or TrollStore storage.
- **Document Properties Inspector ("Get Info"):** Detailed desktop-style inspector displaying storage paths, exact byte size, word and paragraph metrics, paper preset, and TrollStore sandboxing status.
- **In-Place File Operations:** Rename documents, duplicate documents, and export to iOS Files (`On My iPhone → TrollDocs`).

---

## Project Structure

```
TrollDocs/
├── .github/
│   └── workflows/
│       └── build.yml                        # GitHub Actions CI/CD (XcodeGen, xcodebuild, ldid)
├── project.yml                              # XcodeGen project specification
├── Resources/
│   ├── Info.plist                           # UIFileSharingEnabled & document handling
│   ├── TrollDocs.entitlements               # TrollStore container & sandbox entitlements
│   └── Assets.xcassets/                     # App icons and theme colors
└── Sources/
    ├── TrollDocsApp.swift                   # SwiftUI application entry point
    ├── Design/
    │   ├── Theme.swift                      # Editorial typography, paper stock, and ink colors
    │   └── Components.swift                 # Reusable buttons, chips, and hairlines
    ├── Models/
    │   ├── Document.swift                   # PDF document model
    │   ├── DocumentFormat.swift             # Exclusively PDF (.pdf) format definition
    │   ├── DocumentSettings.swift           # Page geometry, paper sizes, margins, and typography
    │   └── RichText.swift                   # Rich document paragraphs and inline runs
    ├── Services/
    │   ├── DocumentStore.swift              # Atomic document persistence in App Support
    │   └── DocumentRenderer.swift           # CoreText multi-page PDF typesetting compiler
    ├── ViewModels/
    │   └── EditorViewModel.swift            # Auto-save pipeline and dirty tracking
    └── Views/
        ├── LibraryView.swift                # PDF catalogue, search, import, and context menus
        ├── EditorView.swift                 # PDF manuscript workspace & rich text controls
        ├── RichTextEditor.swift             # Typography editor canvas
        ├── PDFStudioView.swift              # PDFKit reader, page scrubber, and search
        ├── DocumentPropertiesView.swift     # Desktop "File Properties / Get Info" inspector
        ├── DocumentPickerView.swift         # PDF external file import picker
        ├── InspectorView.swift              # Page setup & typography inspector
        ├── PreviewView.swift                # Instant print preview
        └── ShareSheetView.swift             # System share sheet (AirDrop, Files, Mail)
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

- **Container Mode (`false`):** Standard container mode with full integration with the native iOS **Files** app under `On My iPhone → TrollDocs`.
- **Root Mode (`true`):** Allows TrollDocs to access paths outside the sandbox (`/var/mobile`, root filesystem) if needed.

---

## Automated CI/CD Build via GitHub Actions

1. **Trigger:** Push to `main` branch or manual `workflow_dispatch`.
2. **Environment:** macOS runner (`macos-latest`).
3. **Tool Installation:** Installs `xcodegen` and `ldid` via Homebrew.
4. **Project Generation:** `xcodegen generate` generates `TrollDocs.xcodeproj` from `project.yml`.
5. **Compilation:** Compiles for generic iOS device (`generic/platform=iOS`) in `Release` configuration without signing.
6. **Fake-Signing:** Injects TrollStore entitlements into the Mach-O binary using `ldid -SResources/TrollDocs.entitlements`.
7. **Packaging:** Bundles the app into `Payload/` and creates both `.ipa` and `.tipa`.
8. **Artifact Delivery:** Uploads the builds directly to the GitHub Actions Run summary.
