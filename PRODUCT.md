# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users
Power iOS and TrollStore users on iOS 15.0+ who need desktop-grade document composition, editorial typesetting, and PDF manipulation directly on mobile devices without App Store sandboxing limitations, cloud subscriptions, or arbitrary app restrictions.

## Product Purpose
TrollDocs exists to provide a native, offline, publication-grade PDF creation studio and document manager for iOS. Success means a user can write, format, typeset, inspect, and export publication-ready PDF documents adhering to professional desktop typography standards entirely on their iPhone or iPad.

## Positioning
Unlike generic mobile PDF utilities or subscription-locked office suites, TrollDocs is an offline-first, native Swift/SwiftUI application powered by CoreText typography and native PDFKit. It combines editorial book-craft aesthetics with TrollStore unsandboxed/shared file-system capabilities, offering zero telemetry, zero cloud lock-in, and desktop-level control over page geometry, running headers, folios, and fonts.

## Operating Context
- Installed via TrollStore (or sideloaded) on iOS 15.0+ devices (iPhone & iPad).
- Directly interacts with the iOS Files app (`UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace`) in `Documents/` and optional unsandboxed storage.
- Used in focused writing sessions, legal/academic document preparation, and offline reading/annotation workflows.
- Managed and built using XcodeGen (`project.yml`) in continuous headless Windows-to-GitHub Actions CI/CD environments.

## Capabilities and Constraints
- **Solely PDF**: Exclusively focused on PDF creation, editing, typesetting, and viewing (all non-PDF formats strictly removed).
- **CoreText Typesetting Engine**: Real print-engine pagination, margin presets (Narrow, Normal, Wide, Custom), page sizes (A4, Letter, Legal, A5), orientation, running headers, and page folios.
- **Native PDFKit Studio ("TrollPDF")**: Native PDF inspection, search, multi-page scrolling, zooming, and sharing.
- **Full Appearance Flexibility**: User-switchable Light Mode, Dark Mode, and System appearance.
- **iOS 15.0+ Minimum Deployment Target**: Must strictly use iOS 15.0-compatible SwiftUI and UIKit APIs (e.g. `Text.kerning(_:)` instead of iOS 16 `tracking`).

## Brand Commitments
- **Name**: TrollDocs / TrollDocs PDF
- **Aesthetic**: Editorial book-craft visual language inspired by printed paper, dense ink, and oxblood accent (`#7B2E29` / `#CE8E80`), paired with New York serif, San Francisco default, and monospace measures.
- **Privacy & Sovereignty**: Zero cloud dependencies, zero external tracking, 100% on-device operation.

## Evidence on Hand
- Working SwiftUI codebase under `Sources/` with MVVM architecture.
- Real CoreText PDF rendering engine in `DocumentRenderer.swift`.
- Native PDFKit viewing and searching in `PDFStudioView.swift`.
- TrollStore entitlements configured in `Resources/TrollDocs.entitlements`.
- Automated CI/CD packaging in `.github/workflows/build.yml` producing `.ipa` and `.tipa`.

## Product Principles
1. **Desktop-Grade Typography on Mobile**: Every document rendered must look like a typeset book page, not an HTML-to-PDF print capture.
2. **Total Local Sovereignty**: The user owns their files, their keys, and their workflow with full iOS Files app visibility and no remote dependency.
3. **Fidelity to Platform Ergonomics**: Comply strictly with Apple HIG touch targets, navigation paradigms, safe areas, and dynamic appearances.
4. **Focused Simplicity**: Master one medium (PDF) thoroughly rather than poorly supporting a dozen divergent formats.

## Accessibility & Inclusion
- Full support for system Light and Dark mode appearances with high-contrast text and warm-paper backgrounds.
- Dynamic layout respecting iOS safe areas, minimum 44x44pt touch targets for interactive controls, and clear visual hierarchy.
