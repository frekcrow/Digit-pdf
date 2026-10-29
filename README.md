# TrollDocs (iOS 15.0+)

**TrollDocs** is a desktop-class native iOS Office Suite and document utility specifically designed for **TrollStore** users on iOS 15.0+.

Rather than merely generating static files, TrollDocs provides **complete interactive control** over your documents—allowing you to create, import, edit, calculate, present, and export Word documents, Spreadsheets, Presentations, and PDFs directly on-device without Apple Developer account restrictions, revokes, or 7-day resigning limits.

---

## Desktop-Class Office Modules

### 1. TrollSheets (Spreadsheet Processor — `.csv`, `.xlsx`)
- **Interactive 2D Grid:** Full spreadsheet matrix with alphabetical column headers (`A`, `B`, `C`...) and row headers (`1`, `2`, `3`...).
- **Formula Bar (`fx`):** Displays cell coordinate (e.g., `B3`), accepts formulas and raw values.
- **Formula Calculation Engine:**
  - Range functions: `=SUM(A1:A5)`, `=AVERAGE(B1:B8)`, `=COUNT(C1:C10)`, `=MIN(...)`, `=MAX(...)`.
  - Arithmetic operations: `=A1+B1`, `=A1*C1`, `=A1-B1`, `=A1/B1`.
- **One-Tap AutoSum (`Σ`):** Instantly calculates column sums.
- **Row & Column Operations:** Insert or delete rows and columns dynamically.
- **Column Number Formatting:** General, Currency (`$`), Percentage (`%`), Decimal.
- **Live Status Bar:** Real-time calculation of `SUM`, `AVERAGE`, and `COUNT` for the active column.
- **Dual Export:** Export directly to standard CSV or a paginated, zebra-striped PDF table.

### 2. TrollWord (Word Processor — `.docx`, `.pdf`, `.txt`)
- **Desktop Typography & Formatting:** Heading styles (Title, H1, H2, H3), Body, Blockquote, Code.
- **Inline Text Formatting:** **Bold**, *Italic*, <u>Underline</u>, text alignment.
- **Page Layout Inspector:** Standard paper sizes (A4, US Letter, Legal, A5), Portrait/Landscape, Margin presets (Narrow, Normal, Wide, Custom), and Running Headers/Footers.
- **CoreText Pagination Engine:** Paginated output with running heads and folios.
- **Export Formats:** Print-ready PDF, Word OpenXML (`.docx`), and Plain Text (`.txt`).

### 3. TrollSlides (Presentation Studio — `.pptx`)
- **16:9 Widescreen Slide Canvas:** Desktop slide designer with typography and color themes.
- **Slide Layout Templates:** Title Slide, Bullet Points, Two Columns, Section Header, and Blank.
- **Themes:** Navy Executive, Dark Modern, Editorial Paper, Pine Forest, Crimson Sunset.
- **Slide Filmstrip:** Thumbnail carousel to reorder, add, duplicate, or delete slides.
- **Speaker Notes Drawer:** Keep private notes for each slide.
- **Fullscreen Slideshow Mode ("Play Show"):** Interactive full-screen presentation mode with tap-to-advance navigation.
- **Export:** Export slide decks directly into a 16:9 PDF presentation deck.

### 4. TrollPDF Studio (PDF Reader & Annotator — `.pdf`)
- **Native PDFKit Integration:** Smooth hardware-accelerated viewing and pinch-to-zoom.
- **Full-Text In-Document Search:** Find keywords with highlighted matches and step-through navigation.
- **Page Navigation:** Quick jump to any page and page count scrubber.

### 5. Desktop File Management & External Import
- **Import Any Document:** Integrated `UIDocumentPickerViewController` lets you import any external file (CSV, TXT, PDF, DOCX, XLSX, PPTX) from iOS Files, iCloud Drive, or local storage.
- **Desktop File Inspector ("Get Info"):** Detailed metadata viewer showing storage paths, TrollStore container status, exact byte sizes, content metrics (word/cell/slide counts), and timestamps.
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
    │   ├── Document.swift                   # Unified document model (Word, Sheets, Slides)
    │   ├── DocumentFormat.swift             # Format definitions (PDF, DOCX, CSV, XLSX, PPTX, TXT)
    │   ├── DocumentSettings.swift           # Page geometry, margins, and typography
    │   ├── RichText.swift                   # Rich document paragraphs and inline runs
    │   ├── SpreadsheetModel.swift           # 2D table matrix & formula engine (=SUM, =AVG)
    │   └── PresentationModel.swift          # Slide deck, layouts, themes, and notes
    ├── Services/
    │   ├── DocumentStore.swift              # Atomic document persistence in App Support
    │   └── DocumentRenderer.swift           # Multi-page PDF, CSV, TXT, and OpenXML compilers
    ├── ViewModels/
    │   └── EditorViewModel.swift            # Auto-save pipeline and dirty tracking
    └── Views/
        ├── LibraryView.swift                # Document catalogue, search, filters, and import
        ├── EditorView.swift                 # Top-level workspace router for all office formats
        ├── SpreadsheetEditorView.swift      # TrollSheets 2D table grid & formula bar
        ├── PresentationEditorView.swift     # TrollSlides slide deck editor & slideshow player
        ├── RichTextEditor.swift             # TrollWord rich text typography canvas
        ├── PDFStudioView.swift              # PDFKit reader, page scrubber, and search
        ├── DocumentPropertiesView.swift     # Desktop "File Properties / Get Info" inspector
        ├── DocumentPickerView.swift         # External file import picker
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

- **Container Mode (`false`):** Standard container mode with full integration with the native iOS **Files** app under `On My iPhone -> TrollDocs`.
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
