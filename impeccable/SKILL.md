---
name: impeccable
description: >-
  Use Impeccable for new or substantially redesigned app/site interfaces where visual or UX judgment matters. Standalone technical diagrams and architecture explainer pages use archify; HTML slide decks use html-ppt. Also use for explicit Impeccable commands, new interaction patterns and design audits/polish. Routine copy, spacing, color, CSS or existing-component fixes use ordinary implementation unless design judgment is requested. Not backend work, Office/PDF deliverables, static artwork or external-site inspection without a UI implementation deliverable.
metadata:
  version: 4.9.2
---

<!-- LOCAL ROUTING OVERRIDE START -->
## Usage Rule

Use this skill as the frontend design entry point only when design judgment materially affects the outcome.

### Brief, authorization and rejected designs

These local rules also apply when a reference file or generated CLI directive says otherwise:

- Explicit user requirements and existing authorization control the task. Continue a clearly requested or delegated redesign without repeating settled preference questions, concept tournaments or approval steps. Ask only for missing material information or genuinely unauthorized actions; do not bypass an explicit user review checkpoint.
- Operate/Read are usability modes, not a command to produce neutral, flat or minimally animated visuals. Radius ranges, palette restraint, material restrictions and effect counts are examples. Use the requested visual character, accessible contrast, immediate controls, interruption handling and reduced-motion alternatives together.
- A request to reject or replace the current design permits new composition, icons, typography, colour, material and motion. Preserve product behavior and data contracts, not unapproved visual choices. A later broad rejection supersedes earlier partial acceptance unless the user retains an exception.
- When rejection invalidates design context, move the rejected specifications out of active authority, leave an explicit pending-replacement status, and update the active brief/sidecar consistently. Historical tokens and specimens may be consulted for migration only; do not reload them as brand commitments or invent a replacement approval.
- Give components ownership of their styles and motion. During migration remove replaced rules; do not solve a component requirement with blanket radius rules or document-wide press handlers. A change of component library must preserve click, keyboard, focus and form behavior.
- Validate the real screen and relevant journeys. Builds, screenshots, hashes and functional passes establish their actual scope; none establishes user aesthetic approval. Review requirements should be proportional to the task; a rules-only maintenance request does not require a full UI redesign or browser run.

### Trigger priority

Apply these checks in order:

1. An explicit `$impeccable <command>` request or a direct request to use Impeccable takes priority and should follow the named command's reference. This includes `shape`, `init`, `document`, `extract`, `critique`, `audit`, `polish`, `bolder`, `quieter`, `distill`, `harden`, `onboard`, `animate`, `colorize`, `typeset`, `layout`, `delight`, `overdrive`, `clarify`, `adapt`, `optimize`, `live`, `doctor`, `hooks`, and `pin`/`unpin`.
2. If no command is explicit, route by the final deliverable: standalone technical diagrams or shareable architecture explainer pages belong to `archify`, including “做一个技术架构说明页面”; multi-slide HTML/browser decks belong to `html-ppt`; app/product interfaces with navigation, search, forms or dashboards belong here when design judgment is needed; static artwork and Office/PDF work belong to their format skills. The word “page” alone does not select Impeccable.
3. If the deliverable is a frontend interface, trigger this skill only when visual or UX direction, a new interaction model, or design judgment materially affects the result.
4. If the task is ordinary engineering, a clear small maintenance edit, or runtime verification only, do not trigger this skill.

Trigger it for:

- Designing or building a new frontend page, product surface, visual component, dashboard, landing page, or app screen where visual or UX direction must be established
- Substantially redesigning an existing interface, interaction model, responsive system, onboarding flow, or design system
- Performing a design-focused critique, audit, polish, accessibility pass, or visual quality review

Do not auto-trigger it for routine frontend maintenance when the requested outcome is already clear, including:

- Copy, label, icon, or content replacement
- Isolated spacing, color, typography, token, or straightforward CSS changes
- Small edits to an existing component that do not introduce a new visual direction or interaction model
- Bug fixes, regression fixes, or restoring established behavior
- Generic website or React code work whose primary goal is not interface design
- Browser, Playwright, screenshot, or server verification by itself; use `webapp-testing` only when runtime evidence is required

### Small-change fast path

When the desired result is clear and local, inspect the relevant code and edit it directly.

- Do not require `PRODUCT.md` or `DESIGN.md`
- Do not load an Impeccable command playbook or `craft-floor.md`
- Do not start a development server, browser, Playwright session, screenshot loop, or external deployment by default
- Use only the smallest relevant existing static check when one is useful
- Use one targeted browser or viewport check only when layout, responsive behavior, motion, or interaction cannot be established from code, or when the user explicitly requests visual verification

### Full design path

For new surfaces, substantial redesigns, new interaction systems, durable design-system work, or explicit Impeccable commands, follow the normal Impeccable workflow. Missing `PRODUCT.md` should trigger `init` only when strategic product or design context is genuinely required.

The old standalone design helper skills (`adapt`, `animate`, `audit`, `clarify`, `critique`, `delight`, `distill`, `harden`, `optimize`, `polish`, `typeset`) remain represented as Impeccable reference files and command flows.

Boundary rules:

- Standalone technical diagrams and architecture explainer pages belong to `archify`; technical subject matter in an actual app interface does not change that interface’s routing
- Inspecting an external site's design language without building a UI is handled directly with targeted web access and analysis
- Static poster, cover, PNG, or PDF artwork belongs to `canvas-design`
- HTML or browser slide decks belong to `html-ppt`
- Word, PDF, PowerPoint, and spreadsheet deliverables belong to their format skills
- React performance or component architecture without a design deliverable is ordinary engineering work, not an Impeccable trigger
<!-- LOCAL ROUTING OVERRIDE END -->

This skill gives you the tools and permission to make design that earns the name out-of-distribution craft. Work as an award-winning design director would: production-grade code, a clear POV, a deep grasp of what the client and its users need, and exceptional craft.

Core principles:
- Finish the job. No hedging, no shortcuts: the deliverable is complete, except assets the user must provide.
- Scale ambition to the surface's mode (see Modes). Persuade and Experience get full commitment: bold, distinct work with a point of view. On Operate and Read, ambition shows as precision and restraint, and patterns the visitor already knows earn their place.
- Verify by looking at the rendered result at the sizes it ships at, and batch the checks: fix what one look shows before looking again, rather than screenshotting after every tweak.

## Setup

1. Run `<skill-base-dir>/scripts/impeccable context` once per session, where `<skill-base-dir>` is the directory that contains this SKILL.md (the skill folder, not a plugin root two levels above it); keep cwd at the user's project. That base directory resolves every `.agents/skills/impeccable/scripts/impeccable <verb>` command in this skill and its references, and `.agents/skills/impeccable/scripts` is the fallback only when the runtime reports no base directory. On a Windows shell without `sh`, call `.agents/skills/impeccable/scripts/impeccable.cmd` instead. The launcher runs a self-contained binary that ships next to it or is downloaded once on first run; no Node or other runtime is required. Pass a named source file or route as `--target <path>`. It loads PRODUCT.md, DESIGN.md, the matching surface brief, and native-platform guidance when applicable; follow its directives and do not rerun it.
2. Load the request's playbook: its Commands-table reference for an explicit/implied sub-command, or [reference/new-work.md](reference/new-work.md) for a new surface, a replacement visual world, or a build from an approved comp. Some playbooks come in parts; read the part this request needs in the same step, not when the playbook later mentions it: [reference/new-work-world.md](reference/new-work-world.md) when a visual world is created or replaced (a redesign, a new look, or no established world), [reference/new-work-comp.md](reference/new-work-comp.md) for a build from an approved comp or on a comp-led build path, and [reference/critique-rubric.md](reference/critique-rubric.md) for a critique whose Assessment A runs in this context (a native platform, or no sub-agent tool); a delegated Assessment A gets the rubric's path in its prompt instead. Inspect target and incumbent visual truth before editing. When the app cannot run, start with committed visual-regression goldens or screenshot fixtures; verify target and freshness against current tokens, CSS, components, or assets, resolve conflicts, and compare theme/variant captures.
3. After resolving analysis and direction, read [reference/craft-floor.md](reference/craft-floor.md) immediately before any UI edit, including small refinements. It carries the quality floor, the absolute bans, and the reflexes no detector catches. Do not load it for planning-only work.

**Launcher unavailable:** On refusal or failure, send a separate message **before the next tool call**: “Context loading did not run; I’ll read the existing project context directly.” Then read existing PRODUCT.md and DESIGN.md without inventing missing context, follow applicable steps 2–3, including reading [reference/craft-floor.md](reference/craft-floor.md) immediately before any UI edit, and continue through permitted tools. This applies to planning and editing; launcher failure alone does not block either.

## How to design

- **The brief wins.** Honor pinned aesthetics, eras, materials, fonts, and palettes even when they conflict with a saturated-pattern warning. Redirecting a clear brief toward your taste is failure.
- **Refinement preserves; redesign replaces.** Refinement keeps the incumbent identity, behavior, copy, and everything outside scope. Ask before replacing factual copy or adding claims. Redesign keeps product truth, content, function, native affordances, and constraints, but treats the old look as evidence and anti-reference; choose a replacement world in new-work and replace DESIGN.md. Never split the difference into polish on the discarded look.
- **Loaded symbols stay out of the decoration.** A subject's world does not license emblems tied to militarism, supremacy, or hate movements as motifs, badges, or ornament, such as the Rising Sun flag's rays, the Confederate battle flag, or Nazi-era insignia and their stylised variants; reach for that world's neutral forms instead. Content that documents such a symbol as fact stays as it is.
- **Visual authority is evidence, not a filename.** Missing DESIGN.md alone does not make a project greenfield; new-work decides whether to preserve, expand, or replace the incumbent world.

## Modes

The mode names what the visitor's success looks like on this surface.

- **Persuade:** the visitor decides and acts; design is the product. Landing pages, marketing, campaigns, pricing. Earn attention and action. Ship real imagery when the brief needs it; follow the committed world, not category habit.
- **Operate:** the visitor completes a task. App UI, dashboards, editors, admin, settings, tools. Scanability, consistency, native expectations, and the real usage scene outrank expression. Brand lives in precise details.
- **Read:** the visitor understands something. Docs, articles, guides, help, changelogs. Structure for comprehension, then make the reading experience worth staying in.
- **Experience:** the visitor is inside the work itself. Portfolios, galleries, showcases. Let the artifact lead from the first viewport; the interface recedes.

Choose the mode from the requested surface, not the product, and persist it only in that surface brief. A tool's landing page is still Persuade; a fashion house's documentation is still Read; a docs index is Read, not Persuade. See [new-work.md](reference/new-work.md) for new surfaces and [operate.md](reference/operate.md) for deeper Operate/Read guidance.

## Commands

| Command | Category | Description | Reference |
|---|---|---|---|
| `craft [feature]` | Build | Deprecated alias for an ordinary new-work request | [reference/craft.md](reference/craft.md) |
| `shape [feature]` | Build | Plan UX/UI before writing code | [reference/shape.md](reference/shape.md) |
| `init` | Build | Capture durable product context in PRODUCT.md | [reference/init.md](reference/init.md) |
| `document` | Build | Generate DESIGN.md from existing project code | [reference/document.md](reference/document.md) |
| `extract [target]` | Build | Pull reusable tokens and components into design system | [reference/extract.md](reference/extract.md) |
| `critique [target]` | Evaluate | UX design review with heuristic scoring | [reference/critique.md](reference/critique.md) |
| `audit [target]` | Evaluate | Technical quality checks (a11y, perf, responsive) | [reference/audit.md](reference/audit.md) · native: [reference/audit.native.md](reference/audit.native.md) |
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
| `adapt [target]` | Fix | Adapt for different devices and screen sizes | [reference/adapt.md](reference/adapt.md) · native: [reference/adapt.native.md](reference/adapt.native.md) |
| `optimize [target]` | Fix | Diagnose and fix UI performance | [reference/optimize.md](reference/optimize.md) |
| `live` | Iterate | Visual variant mode: pick elements in the browser, iterate on alternatives | [reference/live.md](reference/live.md) |
| `generate [n] [action] [element]` | Iterate | Variants, versions, or alternatives of a named element to choose from in the live browser; no manual picking | [reference/generate.md](reference/generate.md) |

Routing:

- **No argument:** read [routing.md](reference/routing.md) and present its context-aware menu; never auto-run a command.
- **Explicit or clearly implied request to run a command:** load its reference (native variant on native platforms) and follow it. Ask once if two commands fit.
- **Workflow or command-selection question:** read [Workflow questions](reference/routing.md#workflow-questions).
- **Otherwise:** treat the request as general design work. Missing PRODUCT.md routes a new surface or replacement world through init, then new-work; a narrow refinement of existing code proceeds on the incumbent implementation as `impeccable context` directs, offering init afterward rather than blocking on it.
- `teach` aliases `init`. `craft` is a deprecated alias for ordinary new-work and adds nothing. `shape` owns task discovery, then enters new-work only for visual-world and surface-concept decisions.

After init writes PRODUCT.md, resume without rerunning `impeccable context`; init loads the native platform reference itself when the platform it recorded is `ios`, `android`, or `adaptive`.

**Pin / Unpin:** `"C:/Users/Computer/.agents/skills/impeccable/scripts/impeccable" pin <pin|unpin> <command>` creates or removes a standalone `$<command>` shortcut. Report the script's result concisely; relay stderr verbatim on error.

**Hooks:** `$impeccable hooks <on|off|status|ignore-rule|ignore-file|ignore-value|reset>` manages the design detector hook for this project (auto-runs the detector after UI file edits and surfaces findings). Load [reference/hooks.md](reference/hooks.md) when the user invokes it with any argument.

**Doctor:** `$impeccable doctor` reports and repairs drift between this project's Impeccable artifacts (PRODUCT.md, DESIGN.md and its sidecar, config, surface briefs, the hook) and what this version reads. Load [reference/doctor.md](reference/doctor.md) when the user invokes it, or when they ask what is out of date, stale, or needs refreshing. A `CONTEXT_STALE` directive in Setup's output is the cheap subset of the same report; act on it there per its own instructions rather than running doctor unasked.

**Foundations:** `$impeccable foundations` runs `.agents/skills/impeccable/scripts/impeccable foundations` and walks the user through the product-foundations roadmap (secrets, 404 page, icons, CI and more); `$impeccable foundations <id>` fixes that one item. Load [reference/foundations.md](reference/foundations.md) when the user invokes it.

**Never repair drift as a side effect of a design task.** A `CONTEXT_STALE` finding is reported, not acted on, unless the user asks. The one exception is a finding marked `auto`, which the next write to that file performs anyway.
