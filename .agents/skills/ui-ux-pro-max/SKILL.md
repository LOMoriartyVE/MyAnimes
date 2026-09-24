---
name: ui-ux-pro-max
description: "UI/UX design intelligence for web, mobile, and desktop. This skill should be used when designing, building, reviewing, or fixing interfaces, including pages, components, design systems, accessibility, interaction, responsive layout, typography, color, charts, and stack-specific UI implementation. Searchable local data: 79 searchable styles (50 active), 192 product palettes and reasoning profiles, 74 font pairings, 119 UX guidelines, 105 icons, 17 GSAP presets, 25 chart types, and 22 stacks."
---

# UI/UX Pro Max - Design Intelligence

Searchable local UI/UX guidance: 79 searchable styles (50 active), 192 product palettes and exact reasoning profiles, 74 font pairings, 119 UX guidelines, 105 curated icons, 17 GSAP presets, 25 chart types, and 22 technology stacks.

## When to Apply

Use this Skill when the task involves **UI structure, visual design decisions, interaction patterns, or user experience quality control**: designing new pages, creating/refactoring UI components, choosing color/typography/spacing/layout systems, reviewing UI for UX/accessibility/consistency, implementing navigation/animation/responsive behavior, or improving perceived quality and usability.

Skip it for pure backend logic, API/database design, non-visual performance work, infrastructure/DevOps, or non-visual scripts — unless the task changes how something **looks, feels, moves, or is interacted with**.

## Rule Categories by Priority

| Priority | Category | Impact | Domain | Key Checks (Must Have) | Anti-Patterns (Avoid) |
|----------|----------|--------|--------|------------------------|------------------------|
| 1 | Accessibility | CRITICAL | `ux` | Contrast 4.5:1, Alt text, Keyboard nav, Aria-labels | Removing focus rings, Icon-only buttons without labels |
| 2 | Touch & Interaction | CRITICAL | `ux` | Min size 44×44px, 8px+ spacing, Loading feedback | Reliance on hover only, Instant state changes (0ms) |
| 3 | Performance | HIGH | `ux` | WebP/AVIF, Lazy loading, Reserve space (CLS < 0.1) | Layout thrashing, Cumulative Layout Shift |
| 4 | Style Selection | HIGH | `style`, `product` | Match product type, Consistency, SVG icons (no emoji) | Mixing flat & skeuomorphic randomly, Emoji as icons |
| 5 | Layout & Responsive | HIGH | `ux` | Mobile-first breakpoints, Viewport meta, No horizontal scroll | Horizontal scroll, Fixed px container widths, Disable zoom |
| 6 | Typography & Color | MEDIUM | `typography`, `color` | Base 16px, Line-height 1.5, Semantic color tokens | Text < 12px body, Gray-on-gray, Raw hex in components |
| 7 | Animation | MEDIUM | `ux`, `gsap` | Context-aware timing, Motion conveys meaning, Spatial continuity | One duration for every transition, Animating width/height, No reduced-motion |
| 8 | Forms & Feedback | MEDIUM | `ux` | Visible labels, Error near field, Helper text, Progressive disclosure | Placeholder-only label, Errors only at top, Overwhelm upfront |
| 9 | Navigation Patterns | HIGH | `ux` | Predictable back, Bottom nav ≤5, Deep linking | Overloaded nav, Broken back behavior, No deep links |
| 10 | Charts & Data | LOW | `chart` | Legends, Tooltips, Accessible colors | Relying on color alone to convey meaning |

---

## Design System & Stack Rules

### 1. Mobile-First & Touch Targets
- Minimum touch target: 44×44 dp/px.
- Spacing between clickable items: ≥ 8 dp/px.
- Provide instant active/pressed visual feedback (< 100ms).
- Avoid relying on hover states for critical actions on mobile/touch interfaces.

### 2. Typography & Contrast
- Minimum body text contrast ratio of 4.5:1 against background (WCAG AA).
- Large text (18pt+ or 14pt bold) contrast ratio of 3.0:1.
- Line height: 1.4 – 1.6 for comfortable body readability.
- Clear visual hierarchy: Page title (24–32px bold) > Section header (18–20px bold) > Body (14–16px regular) > Caption/Meta (11–13px).

### 3. Layout & Visual Harmony
- Maintain the 60-30-10 color balance:
  - 60% dominant neutral background / surface.
  - 30% secondary structure (cards, borders, text, neutral containers).
  - 10% accent color (primary CTAs, key status indicators, active tabs).
- Consistent spacing system: 4px base grid (4, 8, 12, 16, 24, 32, 48px).
- Avoid horizontal scroll on mobile viewport; always wrap or constrain flexible items.
- Ensure safe area padding on iOS/Android notch and navigation bars.

### 4. Animation & Transitions
- Micro-interactions: 150ms – 250ms with standard ease (e.g. `Curves.easeOutCubic`).
- Page / Modal transitions: 250ms – 350ms.
- Respect reduced motion settings where appropriate.
- Avoid animating layout-affecting geometry (width/height directly) where transforms (scale/opacity) can be used.
