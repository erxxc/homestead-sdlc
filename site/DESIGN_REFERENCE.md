# Frontend Design Reference Document
## Yamauchi No.10 Family Office — y-n10.com
*Reference document for replicating the design system and aesthetic*

---

## 1. Overall Aesthetic & Design Philosophy

### Concept
The site is a masterclass in **luxury editorial minimalism with cinematic atmosphere**. It reads as a high-prestige institutional identity site — closer to a contemporary art museum or Parisian maison than a typical corporate family office. The defining design principle is *restraint as statement*: almost nothing is decorative, yet everything communicates weight and intention.

### Core Aesthetic Pillars
- **Dark-first, high-contrast** — the experience lives in near-black with selective use of white text and muted color. Every element earns its presence against the dark field.
- **Bilingual typographic tension** — Japanese and English coexist as visual equals, creating a layered reading experience. The two scripts have different natural rhythms (vertical vs. horizontal, dense vs. sparse) and that tension is part of the design.
- **Sequential narrative** — content is gated behind a deliberate entry animation. The site is experienced in time, not scanned spatially. Sections scroll into view with choreographed reveals.
- **Silence as content** — large sections of negative space are not empty; they are pacing. The site breathes heavily.
- **Sound as atmospheric layer** — the site explicitly warns users that sound plays. This is rare and signals that audio is integral to the experience, not a feature.

---

## 2. Color System

### Palette

| Token | Hex (approx) | Usage |
|---|---|---|
| Background Primary | `#0a0a0a` / `#080808` | Page background, dominant surface |
| Background Secondary | `#111111` – `#161616` | Section separators, subtle surface lift |
| Text Primary | `#ffffff` | Headlines, nav, key labels |
| Text Secondary | `#aaaaaa` – `#cccccc` | Body copy, subtitles, supporting text |
| Text Tertiary | `#555555` – `#666666` | Section numbers (01, 02), metadata |
| Accent | `#ffffff` (opacity-based) | Borders, dividers, interactive states |
| Destructive / None | No red/blue/green accent used | Brand avoids semantic color entirely |

### Color Behavior
- **No chromatic accent color**. The palette is achromatic — black, white, and a tonal gray ramp. This is a deliberate choice that forces type, space, and motion to carry all the visual weight.
- Hierarchy is achieved through **opacity and weight**, not hue.
- Borders and dividers are rendered as `rgba(255,255,255,0.08)` to `rgba(255,255,255,0.15)` — subtle, not structural.
- Photography (if used) and the OG share image introduce the only non-neutral tones, but they are treated photographically, not as brand color.

---

## 3. Typography

### Typeface Strategy
The site uses a premium sans-serif for the English content and leverages system or licensed CJK fonts for Japanese, letting the two script systems coexist with equal typographic dignity.

**Observed characteristics:**
- **Display / Headline**: Thin to Light weight (~100–300), wide tracking (`letter-spacing: 0.1em` to `0.25em`). Very large scale — headlines operate at `clamp(60px, 10vw, 140px)` range.
- **Body / Paragraph**: Regular to Light weight, relaxed line-height (`1.8`–`2.0`), moderate tracking. English body is around 16–18px, Japanese body slightly denser in visual mass.
- **Section Numbers**: Monospaced or tabular numerals (`01`, `02`, `03`), treated as design elements — small, tertiary color, generous letter-spacing.
- **Navigation**: All caps or small caps with heavy tracking (`0.3em+`), small size (~12–14px).

### Typographic Scale (approximate)
```
Display (Hero):     80px – 140px  / weight: 100–200 / tracking: 0.1–0.2em
H1 (Section title): 48px – 72px   / weight: 200–300 / tracking: 0.08em
H2 (Sub-heading):   24px – 36px   / weight: 300     / tracking: 0.05em
Body (English):     16px – 18px   / weight: 300–400 / line-height: 1.9
Body (Japanese):    15px – 17px   / weight: 300–400 / line-height: 2.0
Label / Nav:        11px – 14px   / weight: 400–500 / tracking: 0.25–0.4em / UPPERCASE
Section number:     12px – 14px   / weight: 400     / tracking: 0.3em
```

### Bilingual Layout Rules
- Japanese text leads (appears first or above) in section intros — it is the cultural and editorial anchor.
- English text follows, typographically quieter or equal.
- The two language blocks are not merely translations stacked side-by-side; they are given different visual weights and spacing, creating rhythm.
- Consider using `writing-mode: vertical-rl` selectively for Japanese decorative labels.

---

## 4. Layout & Spatial System

### Grid
- **Full-bleed, fluid** — no fixed-width container on the outer shell. The background extends to the viewport edge.
- Content lives in a **centered column** with generous horizontal padding: `clamp(24px, 8vw, 120px)` on each side.
- **No complex multi-column grid** on the main content — the site is largely single-column, using width and margin to create visual hierarchy.
- Leadership / team section uses a **simple 2-column or definition list layout**: role label left, name and bio right.

### Spacing Rhythm
The site uses an **exponential spacing scale**, not a uniform baseline grid. The intervals feel editorial rather than engineered:

```
xs:   8px   — internal component padding
sm:   16px  — between inline elements
md:   40px  — between sub-sections within a section
lg:   80px  — between paragraphs in hero content
xl:   120px — between major sections
2xl:  180px – 240px — full-section vertical breathing room
```

### Section Structure
Each major section (`01. STATEMENT`, `02. LEGACY`, etc.) follows this pattern:
1. **Section number** — small, tertiary, uppercase, tracked wide. Positioned top-left or as a prefix.
2. **Japanese headline** — large, thin weight, full width.
3. **Japanese body** — medium size, relaxed line-height.
4. **Divider / breathing space** — significant vertical gap (80–120px).
5. **English headline** — may be same scale or slightly smaller.
6. **English body** — same scale as Japanese body.

---

## 5. Navigation

### Structure
- **Fixed/sticky top navigation** — minimal. Contains:
  - Logo / wordmark (left-aligned)
  - Section anchor links (right-aligned or centered): `Statement`, `Legacy`, `Philosophy`, `About`
  - A `View` / `Sound` toggle pair (utility controls, far right)
- Navigation items are **sparse** — no dropdowns, no hamburger on desktop, minimal on mobile.

### Behavior
- Nav likely **fades in** after the entry animation completes — it is not visible on the splash/entry screen.
- Active section highlighting via scroll tracking (the section number or link changes opacity as the user scrolls).
- `Sound` toggle controls ambient audio — this is a distinctive interaction pattern worth noting.
- `View` toggle may switch between a default and an alternate reading mode (light/dark or content density).

### Entry Gate
The site has a deliberate **splash / entry screen**:
- Displays the brand name and `Since 2020`.
- Presents a single CTA: **"Enter"** (English) with a note about audio playing.
- This creates a threshold moment — the user must commit to entering. This is a luxury/editorial convention borrowed from fashion houses.

---

## 6. Animation & Motion

This is one of the most distinctive aspects of the site. Motion is **cinematic and choreographed**, not functional.

### Principles
- **Slow is sophisticated**. Durations are long by web standards: `0.8s`–`2.0s` for primary transitions.
- **Easing is custom** — likely `cubic-bezier(0.16, 1, 0.3, 1)` (expo-out) or similar ease-out curves. Nothing linear, nothing bouncy.
- **Staggered reveals** — elements within a section enter sequentially, not simultaneously. The Japanese headline may appear first, followed by the body text, with `200–400ms` delays between each.
- **Opacity-led, transform-assisted** — fades from `opacity: 0` combined with subtle `translateY(20px)` → `translateY(0)` or `translateX` movements.
- **Scroll-triggered** — sections animate in when they enter the viewport, using `IntersectionObserver`.

### Key Animation Moments
| Moment | Behavior |
|---|---|
| Page load / Entry | Fade-in of splash screen content, then user clicks "Enter" |
| Section entry (scroll) | Staggered opacity + translate reveal of headline, then body |
| Nav appearance | Fade-in after entry completes |
| Section number | May draw in or fade earlier than headline, acting as an anchor |
| Leadership cards | Sequential fade-in as user scrolls down the list |

### Motion Spec (CSS approximation)
```css
/* Standard reveal */
.reveal {
  opacity: 0;
  transform: translateY(24px);
  transition: opacity 1.2s cubic-bezier(0.16, 1, 0.3, 1),
              transform 1.2s cubic-bezier(0.16, 1, 0.3, 1);
}
.reveal.visible {
  opacity: 1;
  transform: translateY(0);
}

/* Stagger delays (applied per element) */
.stagger-1 { transition-delay: 0.1s; }
.stagger-2 { transition-delay: 0.3s; }
.stagger-3 { transition-delay: 0.5s; }
.stagger-4 { transition-delay: 0.7s; }
```

---

## 7. Component Patterns

### Hero / Entry Screen
```
Full viewport height (100vh)
Background: #080808
Centered content (vertically and horizontally)
Elements:
  - Wordmark: ~80–120px, weight 200, tracked
  - "Since 2020": small, tertiary color, tracked
  - "Enter": mid-size, border button or plain text link
  - Audio notice: tiny, tertiary, bottom of entry module
```

### Section Header
```
Section number: "01." — uppercase, 12px, tertiary color, 0.3em tracking
Gap: 24px
Japanese headline: 64–80px, weight 200, no tracking or slight positive
Gap: 40px
Japanese body: 17px, weight 300, line-height 2.0, max-width ~600px
Gap: 100px
English headline: 40–56px, weight 300
Gap: 32px
English body: 17px, weight 300, line-height 1.9, max-width ~640px
```

### Philosophy Item (numbered list)
Each philosophy item:
```
Number: "1" — large (80–120px), weight 100, opacity: 0.08–0.12 (watermark style, background)
Japanese text: overlaid on or below watermark number
English text: below Japanese
Subtle top border: rgba(255,255,255,0.1)
```

### Leadership Card
```
Role label: uppercase, 11px, tracked, tertiary color
Divider line: 1px, rgba(255,255,255,0.08)
Title (EN): 14px, weight 400
Name (JP): 18–22px, weight 300
Name (EN): 18–22px, weight 300
Bio (JP): 14px, weight 300, line-height 1.9
Bio (EN): 14px, weight 300, line-height 1.9
```

### Contact Section
```
Minimal: "MAIL" label + email address as a link
Email styled as body text, not a conventional styled button
```

### Footer Navigation
```
Horizontal nav links: Statement / Legacy / Philosophy / About
Separator + social icons (Twitter, Facebook, LinkedIn)
All minimal, low-contrast against dark background
```

---

## 8. Interactive States

### Links & Hover
- **No underlines by default** on most text links.
- Hover state: `opacity` transition from `0.6` → `1.0`, duration `~0.3s`. Nothing translates or scales.
- The "Enter" CTA may have a subtle border or underline treatment.

### Sound Toggle
- Two-state button: active / inactive.
- Visual change: opacity or a small indicator dot.
- No elaborate iconography — text or a minimal symbol.

### Scroll Behavior
- **Smooth scrolling** for anchor navigation.
- **No scroll snap** — the experience is free-flowing, not paginated.

---

## 9. Responsive & Mobile Considerations

### Breakpoints (inferred)
```
Mobile:  < 768px  — single column, reduced type scale, compressed spacing
Tablet:  768–1024px — similar to desktop with reduced padding
Desktop: > 1024px — full experience
```

### Mobile Adaptations
- Type scale reduces: display headlines drop to `clamp(36px, 10vw, 80px)`.
- Horizontal padding tightens: `clamp(20px, 5vw, 40px)`.
- Navigation likely collapses — "Enter" screen may remain full-screen.
- Leadership section stacks to single column.
- Spacing rhythm compresses by ~40–50%.

---

## 10. Technical Observations

### Meta & SEO
- `meta-google: notranslate` — deliberate bilingual experience, they do not want auto-translation.
- `maximum-scale=1` in viewport — prevents user scaling (common on scroll-experience sites).
- Full OG/Twitter card image specified.

### Performance Philosophy
- The site likely lazy-loads section content.
- Audio asset is likely a small ambient loop, loaded after user interaction.
- Animations use CSS transitions + `IntersectionObserver` for scroll reveals (no heavy JS animation library needed, though GSAP is common for this level of choreography).

### Suggested Stack to Replicate
```
Framework:     Vanilla JS or Next.js / Nuxt (minimal JS needed)
Animation:     GSAP ScrollTrigger (for production-grade scroll animation)
              or CSS transitions + IntersectionObserver (lighter)
Fonts:         License a thin grotesque (e.g. Neue Haas Grotesk, Aktiv Grotesk, GT America)
               + CJK font (Noto Sans JP, or a licensed Japanese grotesque)
Audio:         Howler.js (for ambient audio with toggle)
Build:         Vite or similar
```

---

## 11. Design Principles to Carry Forward

When building your own site referencing this aesthetic, internalize these rules:

1. **The absence is the design.** Do not fill space. Let the content breathe to the point of discomfort, then add 30% more space.
2. **Weight is hierarchy.** You do not need color to create visual hierarchy — use font-weight (100 vs 300 vs 500) and size alone.
3. **Time is a design material.** The site takes time to experience. Long animation durations are not slow — they are deliberate. Do not speed them up.
4. **Sound is optional but intentional.** If you include audio, it should be atmospheric and loopable — never jarring or musical in a distracting way.
5. **The entry gate creates stakes.** Making the user click to enter creates the feeling that they are stepping into something. Use this sparingly.
6. **Numbers as texture.** Section numbers (`01.`, `02.`) function as typographic texture and navigation simultaneously. Make them visible but clearly subordinate.
7. **Two languages create rhythm.** Even in a monolingual site, you can create the same rhythm by alternating weight, size, or language register between a headline and its supporting body.
8. **No decorative color.** If you are tempted to add a brand accent color, ask whether the contrast and weight system can do the same work. Often it can.
9. **Photography is spare.** If imagery is used, it is full-bleed, monochromatic or low-saturation, and treated as environmental — not as illustration.
10. **Every interaction is slow and smooth.** No snap, no bounce, no spring. Ease-out curves, long durations, no sudden changes.

---

*Document compiled from analysis of y-n10.com, June 2026.*
