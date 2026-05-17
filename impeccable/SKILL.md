---
name: impeccable
description: >-
  Unified Impeccable frontend design skill. Use when the user wants to design, build, redesign, craft, shape, critique, audit, polish, adapt, animate, clarify, distill, harden, optimize, typeset, delight, bolder, quieter, colorize, layout, onboard, overdrive, teach, document, live, or otherwise improve a frontend interface. Also use for Impeccable command-style requests such as `impeccable craft`, `shape`, `bolder`, `layout`, `colorize`, `live`, `teach`, `document`, or `extract` when the target is a frontend UI/design workflow. Covers normal web pages, landing pages, dashboards, product UI, app shells, components, forms, settings, onboarding, empty states, responsive behavior, typography, spacing, layout, color, motion, UX copy, accessibility, and UI-perceived performance. Do NOT use for live-site design-language extraction, static poster or cover art, HTML slide decks, PowerPoint/PDF/Word/spreadsheet deliverables, or React/Next performance engineering when specialized skills exist.
---

<!-- LOCAL ROUTING OVERRIDE START -->
## Usage Rule

Use this skill as the unified **Impeccable frontend design** entry point.

Trigger it when the task clearly involves one of these goals:

- Designing, building, or redesigning a normal web page, app screen, component, dashboard, landing page, or product surface
- Running Impeccable sub-command style work such as `craft`, `shape`, `teach`, `document`, `extract`, `critique`, `audit`, `polish`, `bolder`, `quieter`, `distill`, `harden`, `onboard`, `animate`, `colorize`, `typeset`, `layout`, `delight`, `overdrive`, `clarify`, `adapt`, `optimize`, or `live`
- Improving visual hierarchy, layout, spacing, typography, color, motion, interaction quality, UX copy, empty states, onboarding, responsive behavior, accessibility, or UI-perceived performance
- Building a complex interactive web app, React demo, mini-app, or multi-component frontend experience when the main goal is UI and feature implementation
- Creating a new page or UI while using another website as visual inspiration, as long as the goal is implementation rather than design-system extraction
- Reviewing or refining an existing frontend surface from a design, UX, craft, or interface-quality perspective

The old standalone design helper skills (`adapt`, `animate`, `audit`, `clarify`, `critique`, `delight`, `distill`, `harden`, `optimize`, `polish`, `typeset`) are now represented as Impeccable reference files and sub-command flows under this skill. Route those requests here instead of expecting separate skill directories.

Treat broad command words carefully:

- `extract` belongs here only when the user means Impeccable's project/design-system extraction from frontend UI code; live-site design-language extraction still belongs to `extract-design`
- `document` belongs here only when generating or refreshing Impeccable `DESIGN.md` context; Word/PDF/PPT/spreadsheet documents belong to the format skills
- `optimize` belongs here for UI-perceived performance, animation smoothness, layout stability, image weight, and frontend experience; React/Next architecture, rendering, hydration, data fetching, or bundle-size engineering belongs to `vercel-react-best-practices`

Do **not** use this by default in these cases:

- Design extraction from a live site, design tokens, CSS variables, Tailwind config, Figma variables, or shadcn theme extraction: prefer `extract-design`
- Static poster, cover, or raster/PDF visual artwork: prefer `canvas-design` when available; otherwise handle inline with restrained, intentional output
- HTML/browser slide decks or explicitly presentation-style HTML artifacts: prefer `html-ppt`
- PowerPoint or `.pptx` deliverables: prefer `pptx` (or the external `ppt-master` workflow for generating a new PPTX from raw materials)
- Existing PDF, Word, spreadsheet, or other file-format processing: prefer the corresponding format skill
- React/Next.js performance, server/client rendering, hydration, data fetching, or bundle-size engineering where code architecture is the main concern: prefer `vercel-react-best-practices`
- Flexible React component API design, boolean prop proliferation, compound components, or reusable component architecture: prefer `vercel-composition-patterns`

If the user says a removed helper name directly, such as `用 polish` or `跑 audit`, interpret that as the matching Impeccable sub-command/reference flow inside this skill. If they say one of the newer Impeccable command names directly, such as `跑 layout`, `用 bolder`, `colorize 这个页面`, `impeccable live`, or `teach this project`, route it here when the target is frontend UI/design work.
<!-- LOCAL ROUTING OVERRIDE END -->

Designs and iterates production-grade frontend interfaces. Real working code, committed design choices, exceptional craft.

## Setup

Before substantial design work or frontend file edits:

1. Try to load context (PRODUCT.md / DESIGN.md) via the loader script.
2. Identify the register and load the matching register reference (brand.md or product.md).
3. **If the user invoked a sub-command (e.g. `craft`, `shape`, `audit`), load its reference file too.** This is non-negotiable: `craft` without `craft.md` loaded means you'll skip the shape-and-confirm step the user expects.

Skipping available context produces generic output that ignores the project. Missing context is not always a blocker: use the rules below to decide whether to continue or teach first.

### 1. Context gathering

Two files, case-insensitive. The loader looks at the project root by default and falls back to `.agents/context/` and `docs/` if the root is clean. Override with `IMPECCABLE_CONTEXT_DIR=path/to/dir` (absolute or relative to cwd).

- **PRODUCT.md**: preferred for substantial design work. Users, brand, tone, anti-references, strategic principles.
- **DESIGN.md**: optional, strongly recommended. Colors, typography, elevation, components.

Load both in one call:

```bash
node "C:/Users/Computer/.agents/skills/impeccable/scripts/load-context.mjs"
```

Consume the full JSON output. Never pipe through `head`, `tail`, `grep`, or `jq`. The output's `contextDir` field tells you where the files were resolved from.

If the output is already in this session's conversation history, don't re-run. Exceptions requiring a fresh load: you just ran `$impeccable teach` or `$impeccable document` (they rewrite the files), or the user manually edited one.

`$impeccable live` already warms context via `live.mjs`. If you've run `live.mjs`, don't also run `load-context.mjs` this session.

If PRODUCT.md is missing, empty, or placeholder (`[TODO]` markers, <200 chars), do not automatically block every task on `$impeccable teach`.

- Run `$impeccable teach` first when the user explicitly invokes `teach`, when the original task is `craft` or `shape`, or when the request needs a complete product/brand/design-system foundation (new product surface, full redesign, brand direction, onboarding strategy, or long-lived design system work). Then resume the original task with the fresh context. If the original task was `$impeccable craft`, resume into `$impeccable shape` before implementation work.
- For small or low-risk UI work (minor polish, spacing, copy labels, local layout fixes, simple component tweaks, screenshots-to-code, or existing-behavior preservation), continue using the repository, user prompt, and visible UI as context. Ask at most one focused question if the missing product context would change the decision.

If DESIGN.md is missing: nudge once per session (*"Run `$impeccable document` for more on-brand output"*), then proceed.

### 2. Register

Every design task is **brand** (marketing, landing, campaign, long-form content, portfolio: design IS the product) or **product** (app UI, admin, dashboard, tool: design SERVES the product).

Identify before designing. Priority: (1) cue in the task itself ("landing page" vs "dashboard"); (2) the surface in focus (the page, file, or route being worked on); (3) `register` field in PRODUCT.md when available. First match wins.

If PRODUCT.md exists but lacks the `register` field (legacy), infer it once from its "Users" and "Product Purpose" sections, then cache the inferred value for the session. Suggest the user run `$impeccable teach` to add the field explicitly. If PRODUCT.md is unavailable and the task is small, infer the register from the task and surface instead of stopping.

Load the matching reference: [reference/brand.md](reference/brand.md) or [reference/product.md](reference/product.md). The shared design laws below apply to both.

## Shared design laws

Apply to every design, both registers. Match implementation complexity to the aesthetic vision: maximalism needs elaborate code, minimalism needs precision. Interpret creatively. Vary across projects; never converge on the same choices. GPT is capable of extraordinary work. Don't hold back.

### Color

- Use OKLCH. Reduce chroma as lightness approaches 0 or 100; high chroma at extremes looks garish.
- Never use `#000` or `#fff`. Tint every neutral toward the brand hue (chroma 0.005–0.01 is enough).
- Pick a **color strategy** before picking colors. Four steps on the commitment axis:
  - **Restrained**: tinted neutrals + one accent ≤10%. Product default; brand minimalism.
  - **Committed**: one saturated color carries 30–60% of the surface. Brand default for identity-driven pages.
  - **Full palette**: 3–4 named roles, each used deliberately. Brand campaigns; product data viz.
  - **Drenched**: the surface IS the color. Brand heroes, campaign pages.
- The "one accent ≤10%" rule is Restrained only. Committed / Full palette / Drenched exceed it on purpose. Don't collapse every design to Restrained by reflex.

### Theme

Dark vs. light is never a default. Not dark "because tools look cool dark." Not light "to be safe."

Before choosing, write one sentence of physical scene: who uses this, where, under what ambient light, in what mood. If the sentence doesn't force the answer, it's not concrete enough. Add detail until it does.

"Observability dashboard" does not force an answer. "SRE glancing at incident severity on a 27-inch monitor at 2am in a dim room" does. Run the sentence, not the category.

### Typography

- Cap body line length at 65–75ch.
- Hierarchy through scale + weight contrast (≥1.25 ratio between steps). Avoid flat scales.

### Layout

- Vary spacing for rhythm. Same padding everywhere is monotony.
- Cards are the lazy answer. Use them only when they're truly the best affordance. Nested cards are always wrong.
- Don't wrap everything in a container. Most things don't need one.

### Motion

- Don't animate CSS layout properties.
- Ease out with exponential curves (ease-out-quart / quint / expo). No bounce, no elastic.

### Absolute bans

Match-and-refuse. If you're about to write any of these, rewrite the element with different structure.

- **Side-stripe borders.** `border-left` or `border-right` greater than 1px as a colored accent on cards, list items, callouts, or alerts. Never intentional. Rewrite with full borders, background tints, leading numbers/icons, or nothing.
- **Gradient text.** `background-clip: text` combined with a gradient background. Decorative, never meaningful. Use a single solid color. Emphasis via weight or size.
- **Glassmorphism as default.** Blurs and glass cards used decoratively. Rare and purposeful, or nothing.
- **The hero-metric template.** Big number, small label, supporting stats, gradient accent. SaaS cliché.
- **Identical card grids.** Same-sized cards with icon + heading + text, repeated endlessly.
- **Modal as first thought.** Modals are usually laziness. Exhaust inline / progressive alternatives first.

### Copy

- Every word earns its place. No restated headings, no intros that repeat the title.
- **No em dashes.** Use commas, colons, semicolons, periods, or parentheses. Also not `--`.

### The AI slop test

If someone could look at this interface and say "AI made that" without doubt, it's failed. Cross-register failures are the absolute bans above. Register-specific failures live in each reference.

**Category-reflex check.** Run at two altitudes; the second one catches what the first one misses.

- **First-order:** if someone could guess the theme + palette from the category alone ("observability → dark blue", "healthcare → white + teal", "finance → navy + gold", "crypto → neon on black"), it's the first training-data reflex. Rework the scene sentence and color strategy until the answer isn't obvious from the domain.
- **Second-order:** if someone could guess the aesthetic family from category-plus-anti-references ("AI workflow tool that's not SaaS-cream → editorial-typographic", "fintech that's not navy-and-gold → terminal-native dark mode"), it's the trap one tier deeper. The first reflex was avoided; the second wasn't. Rework until both answers are not obvious. The brand register's [reflex-reject aesthetic lanes](reference/brand.md) list catches the currently-saturated families.

## Commands

| Command | Category | Description | Reference |
|---|---|---|---|
| `craft [feature]` | Build | Shape, then build a feature end-to-end | [reference/craft.md](reference/craft.md) |
| `shape [feature]` | Build | Plan UX/UI before writing code | [reference/shape.md](reference/shape.md) |
| `teach` | Build | Set up PRODUCT.md and DESIGN.md context | [reference/teach.md](reference/teach.md) |
| `document` | Build | Generate DESIGN.md from existing project code | [reference/document.md](reference/document.md) |
| `extract [target]` | Build | Pull reusable tokens and components into design system | [reference/extract.md](reference/extract.md) |
| `critique [target]` | Evaluate | UX design review with heuristic scoring | [reference/critique.md](reference/critique.md) |
| `audit [target]` | Evaluate | Technical quality checks (a11y, perf, responsive) | [reference/audit.md](reference/audit.md) |
| `polish [target]` | Refine | Final quality pass before shipping | [reference/polish.md](reference/polish.md) |
| `bolder [target]` | Refine | Amplify safe or bland designs | [reference/bolder.md](reference/bolder.md) |
| `quieter [target]` | Refine | Tone down aggressive or overstimulating designs | [reference/quieter.md](reference/quieter.md) |
| `distill [target]` | Refine | Strip to essence, remove complexity | [reference/distill.md](reference/distill.md) |
| `harden [target]` | Refine | Production-ready: errors, i18n, edge cases | [reference/harden.md](reference/harden.md) |
| `onboard [target]` | Refine | Design first-run flows, empty states, activation | [reference/onboard.md](reference/onboard.md) |
| `animate [target]` | Enhance | Add purposeful animations and motion | [reference/animate.md](reference/animate.md) |
| `colorize [target]` | Enhance | Add strategic color to monochromatic UIs | [reference/colorize.md](reference/colorize.md) |
| `typeset [target]` | Enhance | Improve typography hierarchy and fonts | [reference/typeset.md](reference/typeset.md) |
| `layout [target]` | Enhance | Fix spacing, rhythm, and visual hierarchy | [reference/layout.md](reference/layout.md) |
| `delight [target]` | Enhance | Add personality and memorable touches | [reference/delight.md](reference/delight.md) |
| `overdrive [target]` | Enhance | Push past conventional limits | [reference/overdrive.md](reference/overdrive.md) |
| `clarify [target]` | Fix | Improve UX copy, labels, and error messages | [reference/clarify.md](reference/clarify.md) |
| `adapt [target]` | Fix | Adapt for different devices and screen sizes | [reference/adapt.md](reference/adapt.md) |
| `optimize [target]` | Fix | Diagnose and fix UI performance | [reference/optimize.md](reference/optimize.md) |
| `live` | Iterate | Visual variant mode: pick elements in the browser, generate alternatives | [reference/live.md](reference/live.md) |

Plus two management commands: `pin <command>` and `unpin <command>`, detailed below.

### Routing rules

1. **No argument**: render the table above as the user-facing command menu, grouped by category. Ask what they'd like to do.
2. **First word matches a command**: load its reference file and follow its instructions. Everything after the command name is the target.
3. **First word doesn't match**: general design invocation. Apply the setup steps, shared design laws, and the loaded register reference, using the full argument as context.

Setup (context gathering, register) is already loaded by then; sub-commands don't re-invoke `$impeccable`.

If the first word is `craft`, setup still runs first, but [reference/craft.md](reference/craft.md) owns the rest of the flow. If setup invokes `teach` as a blocker, finish teach, refresh context, then resume the original command and target.

## Pin / Unpin

**Pin** creates a standalone shortcut so `$<command>` invokes `$impeccable <command>` directly. **Unpin** removes it. The script writes to every harness directory present in the project.

```bash
node "C:/Users/Computer/.agents/skills/impeccable/scripts/pin.mjs" <pin|unpin> <command>
```

Valid `<command>` is any command from the table above. Report the script's result concisely. Confirm the new shortcut on success, relay stderr verbatim on error.
