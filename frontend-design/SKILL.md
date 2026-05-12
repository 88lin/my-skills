---
name: frontend-design
description: >-
  Create distinctive, production-grade frontend interfaces with high design quality. Generates creative, polished code that avoids generic AI aesthetics. Use for normal UI/feature implementation on web components, pages, apps, React demos, mini-apps, multi-component web apps, landing pages, and product surfaces. Do NOT use by default for design extraction, static poster art, HTML slide decks, PowerPoint generation, or React/Next performance engineering when specialized skills exist.
license: Apache 2.0. Based on Anthropic's frontend-design skill. See NOTICE.md for attribution.
---

<!-- LOCAL ROUTING OVERRIDE START -->
## Usage Rule

Use this skill as the **default web UI and frontend creation** skill.

Trigger it when the task clearly involves one of these goals:

- Designing or implementing a normal web page, app screen, component, dashboard, or landing page
- Building a complex interactive web app, React demo, mini-app, or multi-component frontend experience when the goal is UI and feature implementation
- Iterating on existing frontend UI quality, hierarchy, aesthetics, layout, or interaction design
- Creating product UI where the main output is working frontend code
- Creating a new page or UI while using another website as visual inspiration, as long as the goal is implementation rather than design-system extraction
- Creating a single-page website or landing page when the goal is a normal site experience, even if it borrows some visual inspiration from presentations

Do **not** use this by default in these cases:

- Design extraction from a live site: prefer `extract-design`
- Static poster, cover, or art output: prefer `canvas-design` when available; otherwise handle inline with restrained, intentional output (`canvas-design` is registered on the OpenCode/Codex side only in this setup; Claude Code does not have it)
- HTML/browser slide decks or explicitly presentation-style HTML artifacts: prefer `html-ppt`
- PowerPoint or `.pptx` deliverables: prefer `pptx` (or the external `ppt-master` workflow for generating a new PPTX from raw materials — `ppt-master` runs manually, not a skill)
- React/Next.js performance, rendering, data fetching, hydration, or bundle-size work where engineering quality is the main goal: prefer `vercel-react-best-practices` when available; otherwise apply standard React/Next performance hygiene inline (`vercel-react-best-practices` is registered on the OpenCode/Codex side only in this setup; Claude Code does not have it)
<!-- LOCAL ROUTING OVERRIDE END -->

This skill guides creation of distinctive, production-grade frontend interfaces that avoid generic "AI slop" aesthetics. Implement real working code with exceptional attention to aesthetic details and creative choices.

## Context Gathering Protocol

Design skills produce generic output without project context. You MUST have confirmed design context before doing any design work.

**Required context** — every design skill needs at minimum:
- **Target audience**: Who uses this product and in what context?
- **Use cases**: What jobs are they trying to get done?
- **Brand personality/tone**: How should the interface feel?
- **Register**: brand (marketing/content where design is the product) or product (app/tool UI where design serves the workflow)

Individual skills may require additional context — check the skill's preparation section for specifics.

**CRITICAL**: You cannot infer this context by reading the codebase. Code tells you what was built, not who it's for or what it should feel like. Only the creator can provide this context.

**Gathering order:**
1. **Check current instructions (instant)**: If your loaded instructions already contain a **Design Context** section, proceed immediately.
2. **Check .impeccable.md (fast)**: If not in instructions, read `.impeccable.md` from the project root. If it exists and contains the required context, proceed.
3. **Fallback when neither exists**: Use the minimal template at `~/.agents/skills/frontend-design/impeccable-template.md` as a reference for what's missing, then ask the user **one short question covering the missing fields** (audience, use cases, brand tone, register) and wait briefly for a reply. If the user has not answered yet, only do **low-risk structural work** — layout scaffolding, semantic markup, accessibility plumbing, plain neutral defaults. Do **not** pick a tone, palette, typography direction, or motion vocabulary until the user responds. Do not infer audience, use cases, tone, or register from the codebase alone.

---

## Design Direction

Commit to a BOLD aesthetic direction:
- **Purpose**: What problem does this interface solve? Who uses it?
- **Tone**: Pick an extreme: brutally minimal, maximalist chaos, retro-futuristic, organic/natural, luxury/refined, playful/toy-like, editorial/magazine, brutalist/raw, art deco/geometric, soft/pastel, industrial/utilitarian, etc. There are so many flavors to choose from. Use these for inspiration but design one that is true to the aesthetic direction.
- **Constraints**: Technical requirements (framework, performance, accessibility).
- **Differentiation**: What makes this UNFORGETTABLE? What's the one thing someone will remember?

**CRITICAL**: Choose a clear conceptual direction and execute it with precision. Bold maximalism and refined minimalism both work—the key is intentionality, not intensity.

Before choosing theme or palette, write one sentence of physical scene: who uses this, where, under what ambient light, in what mood. If someone could guess the theme and palette from the category alone ("observability means dark blue", "healthcare means white and teal", "finance means navy and gold"), reject it and choose from the actual scene instead.

Then implement working code that is:
- Production-grade and functional
- Visually striking and memorable
- Cohesive with a clear aesthetic point-of-view
- Meticulously refined in every detail

## Frontend Aesthetics Guidelines

### Typography
→ *Consult [typography reference](reference/typography.md) for scales, pairing, and loading strategies.*

Choose fonts that are beautiful, unique, and interesting when personality matters. Pair a distinctive display font with a refined body font for brand surfaces; for dense product UIs, a well-tuned system or sans stack can be the right answer.

**DO**: Use a modular type scale with fluid sizing (clamp)
**DO**: Vary font weights and sizes to create clear visual hierarchy
**DON'T**: Use overused fonts when personality matters: Inter, Roboto, Arial, Open Sans, Geist, Fraunces, Mona Sans, Plus Jakarta Sans, Space Grotesk, Recoleta, Instrument Sans, or system defaults
**DON'T**: Use monospace typography as lazy shorthand for "technical/developer" vibes
**DON'T**: Put large icons with rounded corners above every heading—they rarely add value and make sites look templated

### Color & Theme
→ *Consult [color reference](reference/color-and-contrast.md) for OKLCH, palettes, and dark mode.*

Commit to a cohesive palette. Pick a color strategy before picking colors: restrained (tinted neutrals + one accent), committed (one saturated color carries the surface), full palette (3-4 deliberate roles), or drenched (the surface is the color). Dominant colors with sharp accents outperform timid, evenly-distributed palettes.

**DO**: Use modern CSS color functions (oklch, color-mix, light-dark) for perceptually uniform, maintainable palettes
**DO**: Tint your neutrals toward your brand hue—even a subtle hint creates subconscious cohesion
**DO**: Reduce OKLCH chroma as lightness approaches white or black; high chroma at extremes looks garish
**DON'T**: Use gray text on colored backgrounds—it looks washed out; use a shade of the background color instead
**DON'T**: Use pure black (#000) or pure white (#fff)—always tint; pure black/white never appears in nature
**DON'T**: Use the AI color palette: cyan-on-dark, purple-to-blue gradients, neon accents on dark backgrounds
**DON'T**: Use gradient text for "impact"—especially on metrics or headings; it's decorative rather than meaningful
**DON'T**: Default to dark mode with glowing accents—it looks "cool" without requiring actual design decisions

### Layout & Space
→ *Consult [spatial reference](reference/spatial-design.md) for grids, rhythm, and container queries.*

Create visual rhythm through varied spacing—not the same padding everywhere. Embrace asymmetry and unexpected compositions. Break the grid intentionally for emphasis.

**DO**: Create visual rhythm through varied spacing—tight groupings, generous separations
**DO**: Use fluid spacing with clamp() that breathes on larger screens
**DO**: Use asymmetry and unexpected compositions; break the grid intentionally for emphasis
**DON'T**: Wrap everything in cards—not everything needs a container
**DON'T**: Nest cards inside cards—visual noise, flatten the hierarchy
**DON'T**: Use identical card grids—same-sized cards with icon + heading + text, repeated endlessly
**DON'T**: Use the hero metric layout template—big number, small label, supporting stats, gradient accent
**DON'T**: Center everything—left-aligned text with asymmetric layouts feels more designed
**DON'T**: Use the same spacing everywhere—without rhythm, layouts feel monotonous

### Visual Details
**DO**: Use intentional, purposeful decorative elements that reinforce brand
**DON'T**: Use colored side-stripe borders (`border-left` or `border-right` greater than 1px as accent) on cards, list items, callouts, or alerts. Rewrite with full borders, background tints, leading numbers/icons, or nothing.
**DON'T**: Use glassmorphism everywhere—blur effects, glass cards, glow borders used decoratively rather than purposefully
**DON'T**: Use rounded elements with thick colored border on one side—a lazy accent that almost never looks intentional
**DON'T**: Use sparklines as decoration—tiny charts that look sophisticated but convey nothing meaningful
**DON'T**: Use rounded rectangles with generic drop shadows—safe, forgettable, could be any AI output
**DON'T**: Use modals unless there's truly no better alternative—modals are lazy

### Motion
→ *Consult [motion reference](reference/motion-design.md) for timing, easing, and reduced motion.*

Focus on high-impact moments: one well-orchestrated page load with staggered reveals creates more delight than scattered micro-interactions.

**DO**: Use motion to convey state changes—entrances, exits, feedback
**DO**: Use exponential easing (ease-out-quart/quint/expo) for natural deceleration
**DO**: For height animations, use grid-template-rows transitions instead of animating height directly
**DO**: Use premium motion materials like blur, filters, masks, clip paths, shadow, or color shifts when they create meaningful polish and remain smooth
**DON'T**: Casually animate layout-driving properties (width, height, padding, margin, top, left)
**DON'T**: Use bounce or elastic easing—they feel dated and tacky; real objects decelerate smoothly

### Interaction
→ *Consult [interaction reference](reference/interaction-design.md) for forms, focus, and loading patterns.*

Make interactions feel fast. Use optimistic UI—update immediately, sync later.

**DO**: Use progressive disclosure—start simple, reveal sophistication through interaction (basic options first, advanced behind expandable sections; hover states that reveal secondary actions)
**DO**: Design empty states that teach the interface, not just say "nothing here"
**DO**: Make every interactive surface feel intentional and responsive
**DON'T**: Repeat the same information—redundant headers, intros that restate the heading
**DON'T**: Make every button primary—use ghost buttons, text links, secondary styles; hierarchy matters

### Responsive
→ *Consult [responsive reference](reference/responsive-design.md) for mobile-first, fluid design, and container queries.*

**DO**: Use container queries (@container) for component-level responsiveness
**DO**: Adapt the interface for different contexts—don't just shrink it
**DON'T**: Hide critical functionality on mobile—adapt the interface, don't amputate it

### UX Writing
→ *Consult [ux-writing reference](reference/ux-writing.md) for labels, errors, and empty states.*

**DO**: Make every word earn its place
**DON'T**: Repeat information users can already see

---

## The AI Slop Test

**Critical quality check**: If you showed this interface to someone and said "AI made this," would they believe you immediately? If yes, that's the problem.

A distinctive interface should make someone ask "how was this made?" not "which AI made this?"

Review the DON'T guidelines above—they are the fingerprints of AI-generated work from 2024-2025.

---

## Implementation Principles

Match implementation complexity to the aesthetic vision. Maximalist designs need elaborate code with extensive animations and effects. Minimalist or refined designs need restraint, precision, and careful attention to spacing, typography, and subtle details.

Interpret creatively and make unexpected choices that feel genuinely designed for the context. No design should be the same. Vary between light and dark themes, different fonts, different aesthetics. NEVER converge on common choices across generations.

Remember: the model is capable of extraordinary creative work. Don't hold back—show what can truly be created when thinking outside the box and committing fully to a distinctive vision.
