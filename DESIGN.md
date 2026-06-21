---
name: Bambuddy
description: Self-hosted command center for Bambu Lab printers and print farms.
colors:
  bambu-green: "#00ae42"
  bambu-green-light: "#00c64d"
  bambu-green-dark: "#009438"
  status-ok: "#22c55e"
  status-error: "#ef4444"
  status-warning: "#f59e0b"
  danger: "#dc2626"
  surface: "#1a1a1a"
  surface-raised: "#2d2d2d"
  surface-recessed: "#3d3d3d"
  ink: "#ffffff"
  ink-secondary: "#a0a0a0"
  ink-muted: "#808080"
  ink-tertiary: "#4a4a4a"
  hairline: "#3d3d3d"
  scrim: "#000000B3"
typography:
  headline:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: "1.5rem"
    fontWeight: 600
    lineHeight: "1.25"
    letterSpacing: "-0.01em"
  title:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: "1.25rem"
    fontWeight: 600
    lineHeight: "1.3"
  body:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: "1rem"
    fontWeight: 400
    lineHeight: "1.5"
  label:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 500
    lineHeight: "1.25"
rounded:
  sm: "4px"
  md: "8px"
  lg: "12px"
  xl: "16px"
  pill: "9999px"
spacing:
  sm: "8px"
  md: "16px"
  lg: "24px"
components:
  button-primary:
    backgroundColor: "{colors.bambu-green}"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.md}"
    padding: "8px 16px"
  button-primary-hover:
    backgroundColor: "{colors.bambu-green-light}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
    padding: "8px 16px"
  button-secondary:
    backgroundColor: "{colors.surface-recessed}"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.md}"
    padding: "8px 16px"
  button-secondary-hover:
    backgroundColor: "{colors.ink-tertiary}"
    textColor: "{colors.ink}"
  button-danger:
    backgroundColor: "{colors.danger}"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.md}"
    padding: "8px 16px"
  button-ghost:
    backgroundColor: "transparent"
    textColor: "{colors.ink-secondary}"
    typography: "{typography.label}"
    rounded: "{rounded.md}"
    padding: "8px 16px"
  input:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: "12px 16px"
  card:
    backgroundColor: "{colors.surface-raised}"
    rounded: "{rounded.lg}"
    padding: "24px"
  toggle:
    backgroundColor: "{colors.surface-recessed}"
    rounded: "{rounded.pill}"
    height: "28px"
    width: "44px"
---

> **Scope note (read this):** This documents the **upstream Bambuddy WEB app's** design
> language. It is **brand/design reference only** for the Android app
> (`apps/filament-assignment-android/`) — not an Android implementation spec. `frontend/`
> is read-only. See `/AGENTS.md`.

# Design System: Bambuddy

## 1. Overview

**Creative North Star: "The Print Farm Console"**

Bambuddy is a control-room instrument panel for a print farm. The operator stands near running machines — printers, AMS units, spools, labels — and glances at a phone, tablet, kiosk, or desktop to answer one question: *what needs my attention next?* The interface is built to answer that question in under a second and to stay readable for the hours between events. Density is a feature here, not noise: a farm operator wants many printer states visible at once, not a curated card. The system is dark-first (workshops are often dim, machines glow), calm in its motion (state changes, not choreography), and ruthless about putting the operator's next action above decoration.

The voice is "calm confidence rather than hype" (PRODUCT.md). Visual confidence comes from restraint: one accent, a tight neutral ramp, consistent affordances screen to screen, and status colors that never lie (green = running, red = down, amber = needs-attention). Typography is a single well-tuned sans (Inter), scaled to a denser-than-default base so tables, printer cards, and AMS slots pack information without crowding. Shadows are quiet and structural — surfaces read as layered tonal steps (surface → raised → recessed) with a soft shadow confirming elevation, never performing it.

This system explicitly rejects **cloud-first SaaS marketing tropes**, **decorative dashboards that hide the primary action**, **mobile flows that require desktop setup at the moment of use**, and **designs that make a print-farm operator read explanatory text while holding a spool or standing beside a machine** (PRODUCT.md anti-references). It is workshop software, not a landing page: it exists to be used repeatedly by an expert, not admired once by a prospect.

**Key Characteristics:**
- Dark-first, neutral ramp with a single green accent reserved for primary actions, current selection, and live state.
- Status colors are fixed and semantic — they never shift with the accent theme, so operator instincts stay constant.
- Dense by default; a `dense` card variant and collapsible sidebar earn space back when the operator needs it.
- Touch-first sizing (44px mobile targets, larger kiosk controls) for phones, gloves, and SpoolBuddy touchscreens.
- Quiet 150–250ms motion that conveys state; `prefers-reduced-motion` is honored everywhere.
- Never relies on color alone for printer/spool/conflict state (PRODUCT.md accessibility).

## 2. Colors: The Console Palette

A dark neutral stage with one confident green. Status colors sit outside the theme so operator signal is invariant; the accent is the only color that follows the user's chosen theme.

### Primary
- **Bambu Green** (#00ae42): the brand anchor and the *only* color used for primary actions, current selection, active navigation, and live/active state. Its rarity is its meaning.
- **Bambu Green — Light** (#00c64d): primary-action hover/press feedback.
- **Bambu Green — Dark** (#009438): pressed/active-emphasis and contrast on bright surfaces.

### Secondary (optional — accent theme family, user-selectable)
The accent is themeable. The default is Bambu Green; alternatives exist (teal #14b8a6, blue #3b82f6, orange #f97316, purple #8b5cf6, red #ef4444). Only one accent is active at a time and it always fills the Primary role above — it never becomes decoration.

### Status (fixed, never theme-shifted)
- **OK / Online** (#22c55e): printer running, spool healthy, success.
- **Error / Offline** (#ef4444): printer down, failed, offline, error.
- **Warning** (#f59e0b): needs attention, heating, low stock.

### Neutral (dark-first ramp; values shown are the default dark theme)
- **Surface** (#1a1a1a): the base canvas (page background, main scroll area).
- **Surface — Raised** (#2d2d2d): cards, headers, sidebars, modals — the primary container.
- **Surface — Recessed** (#3d3d3d): tertiary fills, secondary buttons, track backgrounds, hairline-equivalent borders.
- **Ink** (#ffffff): primary text and icon stroke on dark surfaces.
- **Ink — Secondary** (#a0a0a0): labels, ghost-button text, nav default state.
- **Ink — Muted** (#808080): placeholder text, de-emphasized meta.
- **Ink — Tertiary** (#4a4a4a): disabled/quiet fills, dark-mode placeholder baseline.
- **Hairline** (#3d3d3d): 1px borders and dividers separating tonal layers.
- **Scrim** (#000000B3): modal/drawer backdrop (70% black) for focus capture.

### Named Rules
**The One Accent Rule.** Green is used on the smallest possible footprint — primary actions, current selection, live state. If a screen reads as mostly green, the accent has lost its meaning. The operator's eye should land on the green because almost nothing else is.

**The Invariant Signal Rule.** Status colors (ok/error/warning) are fixed and never swap with the accent theme. An operator who learned "red = down" on day one must never have to relearn it.

**The Workshop-Light Rule.** Body text is Ink (#ffffff) on dark surfaces, never a muted gray on a tinted near-dark. If contrast is even close, push toward the ink end of the ramp. Operators read this in variable workshop lighting and sometimes with gloves; legibility is non-negotiable (WCAG AA).

## 3. Typography

**Display Font:** Inter (fallback: system-ui, sans-serif)
**Body Font:** Inter (fallback: system-ui, sans-serif)

One family. Product UI does not need a display/body pairing; a well-tuned sans carries headings, buttons, labels, body, and dense data. Inter is self-hosted as a variable woff2 (weights 100–900) so the UI renders fully offline — critical for a local-first PWA installed on workshop devices.

**Character:** Technical, neutral, and quietly precise. Inter's even color lets dense printer/AMS tables scan as a block; weight does the hierarchy work that a second typeface would otherwise do.

The root scale is deliberately dense: `html { font-size: 14.4px }` sets `1rem = 14.4px`, so the default body text (14.4px / 1.5 line-height) packs more information per screen than a standard 16px base. Headings use weight 600, not size inflation.

### Hierarchy
- **Headline** (Inter 600, 1.5rem / 21.6px, line-height 1.25): page titles. Rare; most surfaces lead with state, not headings.
- **Title** (Inter 600, 1.25rem / 18px, line-height 1.3): section and card titles.
- **Body** (Inter 400, 1rem / 14.4px, line-height 1.5): the workhorse for all text, form fields, table cells, and meta. Cap prose at 65–75ch where long-form reading occurs; data and tables run denser freely.
- **Label** (Inter 500, 0.875rem / 12.6px, line-height 1.25): buttons, tabs, badges, table headers, and controls. Medium weight distinguishes affordances from body without changing the family.

### Named Rules
**The Weight-Not-Size Rule.** Hierarchy is expressed through weight (600 vs 400) first, size second. A page that climbs to large display type is treating itself like marketing, not a console.

**The Single-Family Rule.** No display serif, no decorative face in UI labels, buttons, or data. A second typeface is forbidden in the product shell.

## 4. Elevation

Hybrid: depth is conveyed primarily by **tonal layering** (surface → raised → recessed) plus 1px hairlines; shadows are quiet and confirm elevation rather than perform it. The product is mostly flat at rest — a card is a tonal step with a hairline — and gains a soft shadow only as a state response (resting vs. active/hover). Three shadow "styles" are user-selectable (Classic, Glow, Vibrant); Classic is the default and the canonical reference here.

### Shadow Vocabulary
- **Card (light)** (`box-shadow: 0 2px 8px rgba(0,0,0,0.08)`): resting card elevation on light surfaces.
- **Card (dark)** (`box-shadow: 0 4px 16px rgba(0,0,0,0.4)`): resting card elevation on dark surfaces — the default console state.
- **Glow (dark)** (`0 4px 20px rgba(0,0,0,0.5), 0 0 40px color-mix(in srgb, var(--accent) 15%, transparent)`): optional accent halo on active/featured surfaces under the Glow style.
- **Modal** (`shadow-2xl` / heavy): modals and popovers lift above the scrim.

### Named Rules
**The Tonal-First Rule.** When in doubt, separate layers with a tonal step and a hairline, not a shadow. A shadow should confirm a surface is elevated; it should not be the only thing telling you.

**The No-Performance Rule.** No decorative drop shadows, no glassmorphism as default, no glow on idle elements. Shadows appear as a response to state — focus, hover, modal, active selection — not as ornament.

## 5. Components

Every interactive component carries the full state set: default, hover, focus, active, disabled, loading, error. Focus is always a 2px ring (offset 2px) in the accent color.

### Buttons
- **Shape:** gently curved corners (8px / `rounded-lg`).
- **Primary:** Bambu Green (#00ae42) fill, Ink text, label typography; hover → Green-Light (#00c64d). Reserved for the one primary action in view.
- **Secondary:** Recessed surface (#3d3d3d) fill, Ink text; hover → Ink-Tertiary (#4a4a4a). The default for most actions.
- **Danger:** #dc2626 fill, Ink text; hover → #b91c1c. Used only for irreversible operations (delete, purge, replace) — high-risk actions are made explicit per PRODUCT.md.
- **Ghost:** transparent fill, Ink-Secondary text; hover → recessed fill, Ink text. For low-emphasis actions in dense toolbars.
- **Sizes:** sm (px-3 py-1.5), md (px-4 py-2), lg (px-6 py-3). **Mobile minimum height 44px** (`min-h-[44px]`) on all sizes for touch/gloves; desktop drops the floor.
- **Focus:** `focus:ring-2 focus:ring-offset-2` in the variant's accent; disabled at 50% opacity with `cursor-not-allowed`.

### Cards / Containers
- **Corner Style:** 12px (`rounded-xl`).
- **Background:** Raised surface (#2d2d2d), 1px hairline border (#3d3d3d), resting card shadow.
- **Density:** normal (header px-6 py-4, content p-6) or **dense** (header px-4 py-2.5, content p-4) via a `CardDensityProvider` context — farm operators switch to dense to fit more units on screen. Nested cards are forbidden.
- **Shadow Strategy:** see Elevation — tonal step + hairline + quiet shadow.

### Inputs / Fields
- **Style:** Raised surface fill (#2d2d2d), 1px recessed border, 8px corners, 12px 16px padding, Ink text, Ink-Muted placeholder.
- **Focus:** 1px border → accent (Bambu Green) + `focus:ring-2 ring-bambu-green/50`. Never rely on color alone to signal focus; the ring is structural.
- **Error / Disabled:** error uses status-error border/tint; disabled dims to tertiary.

### Toggles / Switches
- **Shape:** pill (`rounded-full`), 44×28px on mobile / 36×20px on desktop (larger mobile touch target), accent fill when on, recessed track when off, white knob with soft shadow translating on a 200ms ease-in-out.
- **Focus:** 2px accent ring with offset. `role="switch"` + `aria-checked` for screen readers.

### Navigation
- **Structure:** fixed top bar (56px / `h-14`, raised surface, hairline bottom border, z-40) + collapsible left sidebar (raised surface, hairline right border, `transition-all 300ms`). On mobile the sidebar becomes a drawer behind a 60% black scrim.
- **Items:** `px-4 py-3 rounded-lg`, Ink-Secondary default → Recessed hover fill + Ink text; **active = Bambu Green** text. Sidebar order is user-rearrangeable (`useIsSidebarCompact` collapses to icons).
- **Badges:** 18px pill, bold 10px count, status-colored.

### Chips / Status Dots
- **Status dot:** 12–14px filled circle in status color; a soft green glow on the live/online state. Always paired with text or icon — color never carries state alone.

### Signature: SpoolBuddy Kiosk
A darker, literal-neutral kiosk mode (SpoolBuddy touchscreen) uses a separate zinc-based palette with larger 44–48px controls and 2xl/16px cards tuned for a small touchscreen read at arm's length. It is a deliberate sub-register of the console, not a different system: same accent, same status semantics, same state vocabulary.

## 6. Do's and Don'ts

### Do:
- **Do** reserve Bambu Green for primary actions, current selection, and live state only — ≤ ~10% of any screen.
- **Do** keep status colors fixed across every accent theme; green/red/amber always mean the same thing.
- **Do** enforce a 44px minimum touch target on every mobile control (phones, gloves, repeated scanning).
- **Do** express hierarchy with weight (600 vs 400) before size, on the single Inter family.
- **Do** layer surfaces tonally (surface → raised → recessed) with a 1px hairline; reach for shadow only to confirm state.
- **Do** make high-risk actions explicit — delete/purge/replace/get a dedicated Danger button and a confirmation (PRODUCT.md).
- **Do** pair every status color with text or an icon; never signal printer/spool/conflict state by color alone.
- **Do** honor `prefers-reduced-motion` everywhere (see `index.css`).
- **Do** design the operator's *next action* as the most prominent thing on the screen (PRODUCT.md).

### Don't:
- **Don't** ship **cloud-first SaaS marketing tropes** — no hero-metric templates, no gradient text, no identical card grids, no tiny uppercase tracked eyebrows on every section (PRODUCT.md anti-references).
- **Don't** build **decorative dashboards that hide the primary action** — the operator's next action leads, not ornament.
- **Don't** create **mobile flows that require desktop setup at the moment of use** — every critical action must complete on the device in hand.
- **Don't** make a print-farm operator **read explanatory text while holding a spool or standing beside a machine** — labels are terse, glanceable, and self-evident from context.
- **Don't** expose secrets, duplicate source-of-truth data, or create parallel workflows that conflict with Bambuddy or Spoolman (PRODUCT.md anti-references).
- **Don't** use body text below the Ink ramp for "elegance" — muted gray on a tinted dark fails in workshop light. Push toward Ink.
- **Don't** introduce a second typeface in the product shell, or display type where a label belongs.
- **Don't** apply side-stripe borders (`border-left/right > 1px` accent), gradient text, or glassmorphism as default.
- **Don't** use decorative motion that doesn't convey state; no orchestrated page-load sequences.
