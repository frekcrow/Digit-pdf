# Design System: Modern Cupertino Pro

<!-- impeccable:design-schema 1 -->

## World & Identity
TrollDocs PDF is built on **Modern Cupertino Pro**: a native Apple Human Interface design system that integrates Apple system materials, continuous squircle geometry, semantic dynamic colors, and San Francisco Pro typography. It feels like an authentic, first-party Apple productivity application engineered specifically for iOS 15.0+ and iPadOS.

---

## 1. Color Strategy & Semantic Tokens
The interface utilizes an adaptive semantic color system that responds automatically to Light and Dark Mode appearances, high contrast accessibility settings, and iOS system materials.

### Ground & Structural Surfaces
- **Canvas (`Theme.paper` / `systemGroupedBackground`)**:
  - Light: `#F2F2F7` (Standard iOS Grouped Table Ground)
  - Dark: `#000000` (Pure OLED Deep Black)
- **Inset Surface (`Theme.sheet` / `secondarySystemGroupedBackground`)**:
  - Light: `#FFFFFF` (Crisp elevated squircle card)
  - Dark: `#1C1C1E` (Subtle dark graphite surface)
- **Document Desk (`Theme.desk` / `tertiarySystemGroupedBackground`)**:
  - Light: `#E5E5EA` (Neutral writing desk beneath white manuscript pages)
  - Dark: `#121214` (Darkroom writing desk)

### Ink & Content Hierarchy
- **Primary Ink (`Theme.ink` / `.label`)**:
  - Light: `#1C1C1E` (Dense near-black)
  - Dark: `#FFFFFF` (Pure white)
- **Secondary Ink (`Theme.inkSecondary` / `.secondaryLabel`)**:
  - Light: `#6C6C70`
  - Dark: `#8E8E93`
- **Tertiary Ink (`Theme.inkTertiary` / `.tertiaryLabel`)**:
  - Light: `#AEAEB2`
  - Dark: `#636366`

### Dividers & Separators
- **Hairline Rule (`Theme.rule` / `.separator`)**:
  - Light: `#E5E5EA`
  - Dark: `#38383A`
- **Opaque Rule (`Theme.ruleStrong` / `.opaqueSeparator`)**:
  - Light: `#D1D1D6`
  - Dark: `#48484A`

### Accent & Active States
- **Cupertino Accent Tint (`Theme.accent`)**:
  - Light: `#007AFF` (Apple System Blue)
  - Dark: `#0A84FF` (Adaptive Vibrant Blue)
- **Tint Wash (`Theme.accentWash`)**:
  - Light: `#007AFF` at 12% alpha
  - Dark: `#0A84FF` at 18% alpha

---

## 2. Typography Hierarchy
Typography is anchored on Apple's system fonts with Dynamic Type awareness and deliberate voice allocation:

| Role | Font Family | Size / Weight | Usage |
|---|---|---|---|
| **Large Title** | San Francisco Pro (`sans`) | 34pt Bold | Top-level library navigation headers |
| **Title 2** | San Francisco Pro (`sans`) | 22pt Bold | Section headings & empty state headers |
| **Headline / Card Title** | San Francisco Pro (`sans`) | 16pt Semibold | Document card titles, sheet titles |
| **Body UI** | San Francisco Pro (`sans`) | 14-15pt Regular | Form rows, menus, property values |
| **Badges & Chips** | San Francisco Pro (`sans`) | 10-12pt Semibold | File type pills, segment choices, tool labels |
| **Manuscript Document** | New York (`serif`) | 8-16pt Adjustable | User's authored print manuscript |
| **Tabular Metrics** | SF Mono (`mono`) | 10-12pt Medium | Folios, coordinates, word counts |

---

## 3. Shapes & Continuous Geometry
- **Card Containers (`CupertinoCard`)**: Continuous squircle corners (`cornerRadius: 16`, `style: .continuous`), delicate hairline outline, and 3% black elevation drop shadow.
- **Action Buttons & Chips**: Smooth capsules (`Capsule()`) or rounded rectangles (`cornerRadius: 12, style: .continuous`).
- **Tool Icons**: Circular buttons (`width: 36, height: 36`) with `.tertiarySystemFill` background.

---

## 4. Navigation & Layout Paradigm
- **Standard Navigation Bar**: Native iOS large-title navigation bar collapsing seamlessly to inline on scroll with leading/trailing toolbar items.
- **Contextual Tool Ribbon**: Docked glass tool ribbon with 44×44 pt minimum hit targets and segmented tool modes (Reading, Writing, Annotation).
- **Modality**: Standard `NavigationView` sheets with explicit Cancel and Done navigation items in the top corners.

---

## 5. Accessibility & Ergonomics (Apple HIG)
- **44×44 pt Hit Target**: Every tappable button, icon, and chip enforces a 44×44 pt touch frame.
- **VoiceOver & Accessibility**: Clear `.accessibilityLabel` and `.accessibilityHint` on all icon controls.
- **Haptic Feedback (`Haptics`)**: `UINotificationFeedbackGenerator` used tactfully for destructive confirmation and successful exports.
