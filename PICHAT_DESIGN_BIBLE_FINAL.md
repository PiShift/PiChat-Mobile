# PiChat Design Bible
### The single source of truth for every pixel in the app.

> **Rule #1** — Never hardcode a color, font size, spacing value, radius, or shadow anywhere in the codebase.
> Every visual decision must reference a token from this document and its Dart counterpart.

---

## 0. Design Strategy

### Why a Custom Design System (Not Material, Not Cupertino)

PiChat is a Flutter app targeting iOS and Android equally. The correct approach is a **fully custom brand design system** — not Material Design, not Cupertino.

- **Material Design** is Google's Android style. It looks out of place on iOS (ripple effects, FABs, navigation patterns are all wrong).
- **Cupertino / Liquid Glass** is iOS-only. Apple's Liquid Glass (iOS 26) uses native GPU shaders that don't exist on Android and cannot be faithfully replicated cross-platform.
- **Custom brand system** is Flutter's superpower. Flutter paints every pixel identically on both platforms. PiChat should look the same on a Samsung Galaxy and an iPhone 16 — that consistency *is* the brand.

This is exactly what Telegram and WhatsApp do: they ignore both platform design systems and ship their own consistent UI everywhere. The Flutter team formalized this in late 2025 by decoupling Material and Cupertino from the core framework, explicitly opening the door for custom design systems as first-class citizens.

### Architecture Rules
- Use `MaterialApp` only as a root shell for routing and theming infrastructure.
- **Never** use Material widgets for anything the user sees (no `AppBar`, no `ElevatedButton`, no `Scaffold` ripple).
- Build every visible widget from Flutter primitives: `GestureDetector`, `Container`, `DecoratedBox`, `CustomPaint`.
- All shared widgets are prefixed with `Pi` to distinguish them from Flutter built-ins.

### Brand Personality
**Simple. Trustworthy. Fast.** PiChat is a professional tool — not a toy. The design should feel like a sharp product that happens to look great. Warm and human, but never playful or cluttered.

---

## 1. Brand

### Logo

| Variant | Usage |
|---|---|
| Icon mark (orange circle + arrow) | App icon, loading screens, small contexts |
| Full wordmark — dark on white | Light backgrounds, top app bars |
| Full wordmark — white on orange | Colored app bars, splash screen, onboarding |

### Brand Colors
```
Primary Orange   #FF7300   RGB(255, 115, 0)
Ink Black        #231F20   RGB(35, 31, 32)
```

---

## 2. Color System

### 2.1 Primary Palette — Orange

| Token | Hex | Usage |
|---|---|---|
| `primary50` | `#FFF4E6` | Sent message bubble background |
| `primary100` | `#FFE4BE` | Hover/pressed tint on light surfaces |
| `primary200` | `#FFD193` | Disabled primary button background |
| `primary300` | `#FFBE68` | Progress bars, skeleton shimmer accent |
| `primary400` | `#FFAE46` | Secondary icon tint |
| `primary500` | `#FF7300` | **Primary brand — buttons, active tabs, FAB** |
| `primary600` | `#E86600` | Primary button pressed state |
| `primary700` | `#CC5A00` | Primary button hover (web) |
| `primary800` | `#A34800` | Dark accent on colored headers |
| `primary900` | `#7A3600` | Maximum contrast on orange |

### 2.2 Ink Palette — Dark

| Token | Hex | Usage |
|---|---|---|
| `ink900` | `#231F20` | **Primary text, icons** |
| `ink800` | `#3D3839` | Headings on white |
| `ink700` | `#575354` | Secondary headings |
| `ink600` | `#706C6D` | Secondary text, labels |
| `ink500` | `#8A8687` | Placeholder text, hints |
| `ink400` | `#A3A0A1` | Disabled text |
| `ink300` | `#C4C2C2` | Dividers |
| `ink200` | `#E0DFDF` | Borders, inactive inputs |
| `ink100` | `#F0EFEF` | Surface backgrounds, received bubble |
| `ink50`  | `#F8F7F7` | Page background |

### 2.3 Semantic Colors

| Token | Hex | Usage |
|---|---|---|
| `success500` | `#22C55E` | Online, delivered, open ticket |
| `success100` | `#DCFCE7` | Success badge background |
| `warning500` | `#F59E0B` | Pending ticket |
| `warning100` | `#FEF3C7` | Warning badge background |
| `error500` | `#EF4444` | Missed call, failed, destructive action |
| `error100` | `#FEE2E2` | Error badge background |
| `info500` | `#3B82F6` | Info states, read receipts |
| `info100` | `#DBEAFE` | Info badge background |

### 2.4 Chat-Specific Colors

| Token | Hex | Usage |
|---|---|---|
| `bubbleSent` | `#FFF4E6` | Sent message bubble (primary50) |
| `bubbleSentBorder` | `#FFE4BE` | Sent bubble subtle border (primary100) |
| `bubbleReceived` | `#FFFFFF` | Received message bubble |
| `bubbleReceivedBorder` | `#E0DFDF` | Received bubble border (ink200) |

### 2.5 Neutral / Surface

| Token | Hex | Usage |
|---|---|---|
| `white` | `#FFFFFF` | Cards, dialogs, sheets |
| `background` | `#F8F7F7` | App scaffold background (ink50) |
| `surface` | `#F0EFEF` | Input fields, received bubble (ink100) |
| `overlay` | `#231F2080` | Modal scrim (50% ink900) |

### 2.6 Dark Mode Tokens

> Dark mode is **not** deferred — it ships with v1. All tokens below map 1:1 to the light tokens above.
> Use warm near-blacks — never pure `#000000`. The brand's warmth must survive in dark mode.

| Token | Light | Dark | Notes |
|---|---|---|---|
| `background` | `#F8F7F7` | `#0F0E0D` | Warm near-black |
| `surface` | `#F0EFEF` | `#1A1917` | Cards, nav bar |
| `surfaceRaised` | `#FFFFFF` | `#252321` | Elevated cards, inputs |
| `bubbleSent` | `#FFF4E6` | `#3D2A00` | Deep warm amber — keeps brand in dark |
| `bubbleReceived` | `#FFFFFF` | `#1C1917` | Warm charcoal |
| `textPrimary` | `#231F20` | `#FAF8F5` | Warm white, not pure white |
| `textSecondary` | `#8A8687` | `#9A9896` | Muted text |
| `divider` | `#E0DFDF` | `#2C2A28` | Separators |
| `online` | `#22C55E` | `#30D158` | Active dot |
| `error500` | `#EF4444` | `#FF453A` | Destructive |
| `overlay` | `#231F2080` | `#00000080` | Modal scrim |

---

## 3. Typography

### 3.1 Font Families

**Two fonts — auto-switched per content language.**

| Language | Font | Package |
|---|---|---|
| Latin / English | **Plus Jakarta Sans** | `google_fonts` → `GoogleFonts.plusJakartaSans()` |
| Arabic (RTL) | **Tajawal** | `google_fonts` → `GoogleFonts.tajawal()` |

**Why two fonts?** Tajawal was designed for Arabic and its Latin letterforms are noticeably weaker at display sizes. Plus Jakarta Sans is a warm, geometric Latin font that matches Tajawal's spirit without the compromise. Auto-detect language per text block (check for Unicode range U+0600–U+06FF).

**Tajawal italic** — do not use. Not well-defined. Use weight changes for emphasis instead.

### 3.2 Type Scale

All sizes use the `Sz.sp()` helper (see Section 4.3) — never hardcoded pixel values.

| Token | Size | Weight | Line Height | Font | Usage |
|---|---|---|---|---|---|
| `displayLarge` | sp(28) | 800 | sp(34) | Plus Jakarta Sans / Tajawal | Splash, onboarding hero |
| `displayMedium` | sp(24) | 700 | sp(30) | Plus Jakarta Sans / Tajawal | Section hero text |
| `headlineLarge` | sp(20) | 700 | sp(26) | Plus Jakarta Sans / Tajawal | Screen titles in app bar |
| `headlineMedium` | sp(18) | 700 | sp(24) | Plus Jakarta Sans / Tajawal | Card titles, dialog titles |
| `headlineSmall` | sp(16) | 600 | sp(22) | Plus Jakarta Sans / Tajawal | Contact name in chat header |
| `titleLarge` | sp(15) | 600 | sp(20) | Plus Jakarta Sans / Tajawal | Chat list — contact name |
| `titleMedium` | sp(14) | 600 | sp(19) | Plus Jakarta Sans / Tajawal | Section labels, button text |
| `bodyLarge` | sp(14) | 400 | sp(20) | Plus Jakarta Sans / Tajawal | Chat message text |
| `bodyMedium` | sp(13) | 400 | sp(18) | Plus Jakarta Sans / Tajawal | Chat list preview, general body |
| `bodySmall` | sp(12) | 400 | sp(17) | Plus Jakarta Sans / Tajawal | Timestamps, secondary info |
| `labelLarge` | sp(12) | 600 | sp(16) | Plus Jakarta Sans / Tajawal | Tabs, chips, badges |
| `labelSmall` | sp(10) | 500 | sp(14) | Plus Jakarta Sans / Tajawal | Status labels, tiny tags |

**Arabic line-height note:** Add +0.3 to line height multiplier for Tajawal text (Arabic needs more vertical breathing room). E.g., bodyLarge in Arabic uses `sp(20) * 1.3` line height.

### 3.3 Typography Rules
- **Never go below sp(10)** on any text.
- Timestamps always use `bodySmall` + `ink500` (light) / `textSecondary` (dark).
- Contact names in list always use `titleLarge` + `ink900`, bold when unread.
- Message preview always uses `bodyMedium` + `ink600`.
- No italic anywhere in the app.
- RTL: always wrap Arabic content in `Directionality(textDirection: TextDirection.rtl)`.

---

## 4. Spacing

### 4.1 Base Unit
**4px.** All spacing must be a multiple of 4.

| Token | Value | Usage |
|---|---|---|
| `space2` | 2px | Micro gap (icon-to-label inline) |
| `space4` | 4px | Tight padding within chips/badges |
| `space6` | 6px | Bubble internal vertical padding |
| `space8` | 8px | Standard small gap |
| `space12` | 12px | Chat list item vertical padding |
| `space16` | 16px | Standard screen horizontal margin |
| `space20` | 20px | Section gap |
| `space24` | 24px | Large gap between sections |
| `space32` | 32px | Extra large, form groups |
| `space48` | 48px | Hero section padding |
| `space64` | 64px | Empty state spacing |

### 4.2 Layout Constants

| Element | Value |
|---|---|
| Screen horizontal padding | `space16` (16px) each side |
| App bar height | 56px |
| Bottom nav height | 60px + safe area inset |
| FAB bottom offset | `space16` from bottom nav top |
| Min tap target | 44 × 44px |
| Chat list tile height | 72px |
| Chat bubble max width | 75% of screen width |

### 4.3 Dynamic Sizing Helper (Required)

All sizes scale with screen width via `MediaQuery`. Never hardcode pixel values for fonts or dimensions.

```dart
// lib/core/theme/app_sizing.dart
class Sz {
  static double sp(BuildContext ctx, double v) =>
      v * MediaQuery.of(ctx).size.width / 390;

  static double w(BuildContext ctx, double v) =>
      MediaQuery.of(ctx).size.width * v / 390;

  static double h(BuildContext ctx, double v) =>
      MediaQuery.of(ctx).size.height * v / 844;
}

// Usage — always use Sz, never raw values:
fontSize: Sz.sp(context, 14)
width: Sz.w(context, 44)
height: Sz.h(context, 56)
```

---

## 5. Border Radius

| Token | Value | Usage |
|---|---|---|
| `radiusXS` | 4px | Chips, badges, small tags |
| `radiusSM` | 8px | Input fields, context menu items |
| `radiusMD` | 12px | Cards, contact info blocks |
| `radiusLG` | 16px | Bottom sheets (top corners), dialogs |
| `radiusXL` | 20px | Sent/received message bubbles |
| `radiusFull` | 999px | Avatars, pills, FAB, icon buttons |

### Chat Bubble Radius Rules
```
Sent message (right side):
  topLeft: radiusXL, topRight: radiusXL
  bottomLeft: radiusXL, bottomRight: radiusXS   ← tail corner

Received message (left side):
  topLeft: radiusXL, topRight: radiusXL
  bottomLeft: radiusXS, bottomRight: radiusXL   ← tail corner

Grouped messages (same sender, within 2 min, not last):
  All corners: radiusXL   ← no tail
```

---

## 6. Shadows & Elevation

| Token | Specs | Usage |
|---|---|---|
| `shadow0` | none | Flat surfaces, chat bubbles |
| `shadow1` | `0 1px 3px rgba(35,31,32,0.08)` | Cards, list tiles |
| `shadow2` | `0 2px 8px rgba(35,31,32,0.10)` | Bottom nav, floating action bar |
| `shadow3` | `0 4px 16px rgba(35,31,32,0.12)` | Bottom sheets, FAB |
| `shadow4` | `0 8px 32px rgba(35,31,32,0.16)` | Modals, dialogs |

---

## 7. Motion & Animation

**Principle:** Fast and purposeful. No decoration for decoration's sake.

| Token | Duration | Curve | Usage |
|---|---|---|---|
| `durationFast` | 150ms | `easeOut` | State changes (color, opacity) |
| `durationNormal` | 250ms | `easeInOut` | Page transitions, sheet open |
| `durationSlow` | 350ms | `easeInOut` | Modal appear, large layout shifts |
| `durationVerySlow` | 500ms | `easeInOut` | Splash, onboarding |

### Rules
- Bottom sheets slide up in `durationNormal`.
- Dialogs fade + scale (95%→100%) in `durationFast`.
- Tab switches: `durationFast` crossfade — no slide.
- Never animate more than 2 properties simultaneously.
- Message send button: scale 0.95→1.0 on tap (durationFast).
- Haptic feedback on: message send, long-press bubble, call connect.

---

## 8. Iconography

**Package:** `lucide_icons` — clean, 2px stroke weight, consistent cross-platform.

| Context | Size |
|---|---|
| Bottom nav icons | `Sz.w(ctx, 24)` |
| App bar action icons | `Sz.w(ctx, 22)` |
| Inline text icons | `Sz.w(ctx, 16)` |
| Chat attachment options | `Sz.w(ctx, 28)` |
| Empty state illustrations | `Sz.w(ctx, 64)` |

**Color rules:**
- Default: `ink600`
- Active / primary: `primary500`
- Destructive: `error500`
- Active nav tab: use **filled** variant if available, else `primary500` tint

**Custom SVG icons** (brand-specific): use `flutter_svg: ^2.0.0`. Keep stroke weight consistent at 2px.

### Core Chat Icon Reference (Lucide names)
```
MessageCircle    → Chats nav tab
Phone            → Calls nav tab / phone call action
Users            → Groups nav tab
Settings         → Settings nav tab
Send             → Send message button
Paperclip        → Attachment picker
Camera           → Camera option
Mic              → Voice message
Smile            → Emoji picker
Search           → Search bar prefix
CheckCheck       → Read receipt (double tick)
Lock             → Encrypted indicator
MoreVertical     → Options overflow
ArrowLeft        → Back button
Video            → Video call
Bell             → Notifications
```

---

## 9. Component Specs

### 9.1 Buttons

#### Primary Button
```
Height: Sz.h(ctx, 48)
Border radius: radiusFull
Background: primary500
Text: white, titleMedium, weight 600
Pressed: primary600
Disabled: primary200 background + ink400 text
Loading: CircularProgressIndicator(color: white, strokeWidth: 2), 20px
Padding: horizontal space24
```

#### Secondary Button (Outlined)
```
Height: Sz.h(ctx, 48)
Border radius: radiusFull
Background: transparent
Border: 1.5px solid primary500
Text: primary500, titleMedium, weight 600
Pressed: primary50 background
Disabled: ink200 border + ink400 text
```

#### Ghost / Text Button
```
Height: Sz.h(ctx, 40)
Background: transparent
Text: primary500, titleMedium
Pressed: primary50 background, radius radiusSM
No border
```

#### Destructive Button
```
Height: Sz.h(ctx, 48)
Border radius: radiusFull
Background: error500
Text: white, titleMedium, weight 600
Pressed: #DC2626
```

#### Icon Button
```
Size: Sz.w(ctx, 40) × Sz.w(ctx, 40)
Border radius: radiusFull
Background: transparent
Pressed: ink100 background
Icon: Sz.w(ctx, 22), ink600 default
```

#### FAB
```
Size: Sz.w(ctx, 56) × Sz.w(ctx, 56)
Border radius: radiusFull
Background: primary500
Icon: Sz.w(ctx, 24), white
Shadow: shadow3
```

---

### 9.2 Input Fields

#### Standard Text Input
```
Height: Sz.h(ctx, 52)
Border radius: radiusSM (8px)
Background: white (focused) / ink50 (unfocused)
Border: 1px ink200 → 2px primary500 (focused) → 2px error500 (error)
Label: bodySmall, ink500 (floats on focus)
Text: bodyLarge, ink900
Hint: bodyLarge, ink400
Padding: horizontal space16, vertical space14
Error text: bodySmall, error500, below field
```

#### Search Input
```
Height: Sz.h(ctx, 44)
Border radius: radiusFull
Background: ink100
Prefix icon: search, Sz.w(ctx, 20), ink400
Border: none (unfocused) → 1.5px primary500 (focused)
Text: bodyMedium, ink900
```

#### Chat Message Input
```
Min height: Sz.h(ctx, 48), max height: Sz.h(ctx, 120) (multiline)
Border radius: radiusFull (single line) → radiusLG (multiline)
Background: ink50
Border: 1.5px ink200 (unfocused) → 1.5px primary500 (focused)
Padding: horizontal space16, vertical space12
```

---

### 9.3 Avatar

| Variant | Size | Border radius |
|---|---|---|
| XS | `Sz.w(ctx, 28)` | radiusFull |
| SM | `Sz.w(ctx, 36)` | radiusFull |
| MD | `Sz.w(ctx, 44)` | radiusFull |
| LG | `Sz.w(ctx, 56)` | radiusFull |
| XL | `Sz.w(ctx, 80)` | radiusFull |

**Fallback (no image):** Colored circle with initials.
- Extract up to 2 initials from contact name.
- If name is a phone number → use Phone icon.
- Background: deterministically picked from 6 muted tones:
  `[#E8D5FF, #D5E8FF, #D5FFE8, #FFE8D5, #FFD5D5, #D5F0FF]`
- Initials: `labelLarge`, matching darker shade of background.

**Indicators (bottom-right of avatar):**
- Unread: 10px orange dot (`primary500`, shadow1)
- Online: 10px green dot (`success500`)

---

### 9.4 Badge / Chip

#### Status Badge
```
Height: 20px
Padding: horizontal space8
Border radius: radiusXS (4px)
Text: labelSmall, weight 600
```

| Status | Background | Text |
|---|---|---|
| OPEN | `success100` | `success500` |
| PENDING | `warning100` | `warning500` |
| CLOSED | `ink100` | `ink500` |
| UNREAD | `primary500` | `white` |

#### Filter Chip
```
Height: 32px
Padding: horizontal space12
Border radius: radiusFull
Active: primary500 bg, white text, labelLarge 600
Inactive: transparent bg, ink100 border 1px, ink600 text
```

#### Count Badge (unread)
```
Min size: 20×20px, expands for 3+ digits
Border radius: radiusFull
Background: primary500
Text: labelSmall, white, weight 700
```

---

### 9.5 Chat List Item

```
Height: Sz.h(ctx, 72)
Padding: horizontal space16, vertical space12
Divider: 1px ink200 starting at avatar right edge

Layout:
  [Avatar MD] [space12] [Name + preview column] [Timestamp + badge column]

Name row:
  - Contact name: titleLarge, ink900
  - Unread: fontWeight 700, ink900
  - Timestamp: bodySmall, ink400, right-aligned

Preview row:
  - Preview text: bodyMedium, ink500, max 1 line, truncated
  - Unread: ink900, weight 500
  - Unread badge: right-aligned, count badge
  - Delivery icon: ✓✓ info500 (read) / ink300 (sent)

Attachment prefix:
  📎 Attachment  |  🎤 Voice  |  📄 Document  |  📍 Location
```

---

### 9.6 Chat Message Bubble

#### Sent (right-aligned)
```
Max width: 75% of screen width
Background: bubbleSent (#FFF4E6 light / #3D2A00 dark)
Border: 1px bubbleSentBorder
Border radius: per Section 5 tail rules
Padding: space8 horizontal, space6 vertical
Text: bodyLarge, ink900 (light) / textPrimary (dark)
Timestamp: bodySmall, ink400, bottom-right
```

#### Received (left-aligned)
```
Max width: 75% of screen width
Background: bubbleReceived (#FFFFFF light / #1C1917 dark)
Border: 1px bubbleReceivedBorder
Same layout, mirrored
```

#### Message Grouping Rules
- Same sender, within 2 minutes → grouped (no tail, 2px vertical gap)
- New sender or gap >2 min → full bubble with tail (8px gap)
- Date separator: centered pill, bodySmall, ink500 on ink100 background

#### Special Message Types

**Audio:**
```
Width: Sz.w(ctx, 220)
[play/pause icon] [waveform] [duration]
Icon: primary500
```

**Image:**
```
Max width: Sz.w(ctx, 240), aspect ratio preserved
Border radius: radiusLG
Timestamp overlaid on gradient at bottom
```

**Document:**
```
[📄 icon primary500] [filename bodyMedium] [filesize bodySmall ink400]
Background: same as bubble
```

**Contact card:**
```
Width: Sz.w(ctx, 220)
[Avatar SM] [Name titleMedium] [Phone bodySmall ink500]
Bottom divider + "Message" ghost button (primary500)
```

**Location:**
```
Width: Sz.w(ctx, 220), height: Sz.h(ctx, 120) map thumbnail
Border radius: radiusLG
"Open in Maps" label overlay center
```

---

### 9.7 App Bar

#### Standard
```
Height: 56px
Background: white (light) / surface (dark)
Bottom border: 1px ink200 (light) / divider (dark)
Title: headlineLarge, ink900
Leading: Icon Button (back or menu)
Actions: Icon Buttons (max 2), spaced space8
```

#### Chat App Bar
```
Background: white / surface
Leading: back arrow + Avatar SM + [name headlineSmall + status bodySmall ink500]
Actions: phone icon + overflow (⋮)
Tapping the header → opens Contact Details
```

#### Colored App Bar
```
Background: primary500
All text/icons: white
Status bar: light icons
```

---

### 9.8 Bottom Navigation Bar

```
Height: 60px + bottom safe area
Background: white (light) / surface (dark)
Top border: 1px ink200 (light) / divider (dark)
Shadow: shadow2

Tabs: Chats · Calls · Groups · Templates · Campaigns · Settings
Active: primary500 icon + label, primary50 pill behind icon (40×28px, radiusFull)
Inactive: ink400 icon + label
Label: labelSmall (sp(10))
```

---

### 9.9 Bottom Sheet

```
Background: white / surface
Top corners: radiusLG (16px)
Handle: 4×32px, ink200, centered, 12px from top
Shadow: shadow4
Drag to dismiss: always enabled
```

#### Action Sheet
```
Title row: bodyMedium ink500, space16 padding
Items: 56px height, leading icon (sp(22)), label titleMedium ink900
Destructive item: error500 icon + text
Cancel: always last, separated by divider
```

#### Form Sheet
```
Title: headlineMedium ink900, bottom border 1px ink200
Body: space16 all sides
Inputs: stacked, space16 apart
Actions: full-width buttons, space16 margin
```

---

### 9.10 Dialog / Modal

```
Width: screen width - space32
Background: white / surface
Border radius: radiusLG (16px)
Shadow: shadow4
Scrim: overlay
Animation: fade + scale 95%→100%, durationFast

Structure:
[Top padding space24]
[Icon optional, sp(48), centered]
[Title: headlineMedium, ink900, centered, top space12]
[Body: bodyMedium, ink600, centered, horizontal space24, top space8]
[Divider, top space24]
[Actions: space-between, horizontal space16, bottom space16]
  Cancel → Ghost button
  Confirm → Primary or Destructive button
```

---

### 9.11 Quick Reply Panel

```
Presentation: Modal bottom sheet (partial height)
Handle: visible
Title: ⚡ icon (primary500) + "Quick Replies" headlineMedium + X close
Search: search input, full width, space16 top
List: shortcut chip (labelLarge, primary50+primary500) + message preview
Empty state: "No quick replies yet. Create one in Templates."
```

---

### 9.12 Attachment Picker

```
Presentation: Bottom sheet
Grid: 3 columns
Item: sp(72) circle (ink100 bg) + icon (sp(28), ink600) + label bodySmall ink600

Items:
  Gallery    → image icon
  Camera     → camera icon
  Location   → map-pin icon
  Contact    → user icon
  Document   → file-text icon
```
> ⚡ Quick Reply is **not** in this sheet — it's a dedicated button in the chat input bar.

---

### 9.13 Template Card

```
Background: white / surface
Border: 1px ink200
Border radius: radiusMD (12px)
Left accent: 4px colored strip
  UTILITY        → info500
  MARKETING      → primary500
  AUTHENTICATION → success500
Shadow: shadow1

Layout:
[Name: titleMedium ink900] [Category chip right-aligned]
[Preview: bodyMedium ink600, max 2 lines]
[Variable chips: primary50 bg, primary500 border+text, radiusXS]
```

---

### 9.14 Empty State

```
Layout: centered column
Illustration icon: sp(64), ink200
Title: headlineMedium, ink900, centered, top space16
Subtitle: bodyMedium, ink500, centered, horizontal space32, top space8
CTA (if applicable): Primary button, top space24, width auto
```

---

### 9.15 In-App Notification Banner

```
Position: top of screen, below status bar
Background: ink900
Border radius: radiusLG, horizontal space16 margin
Shadow: shadow3
Height: 64px
Layout: [Avatar SM] [space12] [name + preview column] [space12] [X icon]
Name: titleMedium, white
Preview: bodySmall, ink300
Auto-dismiss: 4 seconds
Tap: navigates to chat
```

---

### 9.16 Contact Details Screen Blocks

#### Info Block
```
Background: white / surface
Border radius: radiusMD
Border: 1px ink200
Padding: space16
Label: bodySmall ink500 (above each field)
Value: bodyLarge ink900
Fields separated by divider + space12
```

#### Ticket Status Block
```
Same card as info block
Status badge: top-right inside card header
Assign + Status buttons: secondary outlined, Sz.h(ctx, 40), flex 1 each
```

---

## 10. Screen Layout Patterns

### Standard Screen
```
App Bar (56px)
├── Body (scrollable, background color)
│   ├── horizontal padding: space16
│   └── content sections with space20 gap
└── [FAB or bottom action if needed]
```

### Chat Screen
```
Chat App Bar (56px)
├── MessageList (full width — bubbles self-manage padding)
└── Input Area
    ├── Attachment button (+) → attachment sheet
    ├── Quick reply button (⚡) → quick reply panel
    ├── ChatMessageInput (flex)
    ├── Emoji button
    └── Send / Record toggle (primary500 FAB when text present)
```

### Modal Screen
```
Colored or white app bar with close (X) leading
Full-screen sheet, scrollable body
Fixed bottom: Primary CTA, space16 margin, full width
```

---

## 11. Dart File Map

| File | Contents |
|---|---|
| `lib/core/theme/app_colors.dart` | All color tokens as `const Color`, light + dark |
| `lib/core/theme/app_typography.dart` | All `TextStyle` tokens, both fonts |
| `lib/core/theme/app_spacing.dart` | All spacing + radius + shadow values |
| `lib/core/theme/app_sizing.dart` | `Sz` helper class (sp/w/h dynamic scaling) |
| `lib/core/theme/app_theme.dart` | `ThemeData` wiring |
| `lib/shared/widgets/buttons/` | `PiButton`, `PiIconButton`, `PiFab` |
| `lib/shared/widgets/inputs/` | `PiTextField`, `PiSearchField`, `PiChatInput` |
| `lib/shared/widgets/avatar/` | `PiAvatar` |
| `lib/shared/widgets/badges/` | `PiStatusBadge`, `PiCountBadge`, `PiFilterChip` |
| `lib/shared/widgets/sheets/` | `PiBottomSheet`, `PiActionSheet` |
| `lib/shared/widgets/dialogs/` | `PiDialog` |
| `lib/shared/widgets/chat/` | `PiChatBubble`, `PiChatListItem`, `PiMessageInput` |
| `lib/shared/widgets/empty_state/` | `PiEmptyState` |
| `lib/shared/widgets/template/` | `PiTemplateCard` |
| `lib/shared/widgets/notification/` | `PiNotificationBanner` |

> **Naming convention:** All shared widgets are prefixed with `Pi` — instantly recognizable and distinct from Flutter built-ins.

---

## 12. Rules Summary

### Always ✅
- Reference a named token for every color, size, spacing, and radius
- Use `Sz.sp()` / `Sz.w()` / `Sz.h()` for all sizes
- Use `GestureDetector` for all tappable custom widgets
- Wrap Arabic text in `Directionality(textDirection: TextDirection.rtl)`
- Auto-detect language per message bubble and switch font accordingly
- Define dark equivalents for every token
- Use Plus Jakarta Sans for Latin, Tajawal for Arabic

### Never ❌
- Hardcode any `Color(0xFF...)`, pixel value, or raw `double` for spacing
- Use Material widgets for anything the user sees (no `AppBar`, `ElevatedButton`, `Scaffold` with ripple)
- Use Cupertino widgets (not cross-platform)
- Use `Colors.white` or `Colors.black` directly — use tokens
- Use italic Tajawal
- Go below sp(10) for any text
- Place more than 2 action icons in any app bar

---

*PiChat Design Bible — Final Merged v1.0 — May 2026*
*Sources: DESIGN_SYSTEM.md (component specs, token system, Dart map) + Design Bible v2 (strategy, dark mode, dual fonts, dynamic sizing)*
