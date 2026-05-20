---
name: extract-design
description: >-
  Extract the full design language from any website URL as the primary deliverable. Produces 8 output files including AI-optimized markdown, visual HTML preview, Tailwind config, React theme, shadcn/ui theme, Figma variables, W3C design tokens, and CSS variables. Also runs WCAG accessibility scoring. Use when the user wants to inspect, analyze, extract, or document a live website's visual style or design system — colors, fonts, spacing, shadows, radii, component patterns, motion style, design tokens, or CSS variables. Good fit for queries like 'what colors/fonts does this site use', '看看这个网站的配色 / 字体 / 间距体系', '我想拿到这个网站的设计 tokens', or '/extract-design'. Do NOT use when the goal is to build a new page or UI that merely takes another website as visual inspiration — that is implementation work and belongs to `impeccable`.
allowed-tools: Bash, Read, Write, Glob
---

<!-- LOCAL ROUTING OVERRIDE START -->
## Usage Rule

Use this skill **on demand**, not by default.

Trigger it only when the task clearly involves one of these goals:

- Extracting a website's design system or design language as the deliverable
- Inspecting or documenting a website's visual style so the user can study or reuse it
- Understanding colors, fonts, spacing, shadows, radii, component patterns, or motion style from a live site
- Generating design tokens, CSS variables, Tailwind config, shadcn theme, or Figma variables from an existing website
- Comparing multiple websites or brands from a design-system perspective

This includes intent patterns like:

- `看看这个网站的样式/配色/字体/间距体系`
- `把这个网站的设计 tokens 提取出来`
- `我想了解这个网站的设计语言`

You should **not** require exact words like `extract`, `design system`, or `tokens`. If the user's real goal is to understand and document a website's visual language as the deliverable, this skill can be the right fit even when they phrase it casually.

Disambiguation with `impeccable`:

- `参考这个网站的风格做一个页面` / `按这个网站的设计语言做一个 landing page` / `仿照这个网站做一个 UI` → the deliverable is a **new page/UI**, with another site as visual inspiration. This is implementation work and belongs to `impeccable`. Do NOT trigger `extract-design` just because a reference URL appears.
- `把这个网站的设计语言提取出来` / `我想看它的 colors/fonts/tokens` / `生成它的 Tailwind config / shadcn theme` → the deliverable is the **design system itself**. This is `extract-design`.

Do **not** use this as the default skill for everyday UI design work, polish, critique, or typography improvements. For normal UI creation or iteration, prefer `impeccable` and only use this skill when a real extraction task is needed.

Do **not** trigger it for a vague `看看这个项目` or `看看这个网站` unless the context is clearly about visual design language rather than product logic, content, or code structure.
<!-- LOCAL ROUTING OVERRIDE END -->

# Extract Design Language

Extract the complete design language from any website URL. Generates 8 output files covering colors, typography, spacing, shadows, components, breakpoints, animations, and accessibility.

## Prerequisites

Ensure `designlang` is available. Install if needed:

```bash
npm install -g designlang
```

Or use npx (no install required):

```bash
npx designlang <url>
```

## Process

1. **Run the extraction** on the provided URL:

```bash
npx designlang <url> --screenshots
```

For multi-page crawling: `npx designlang <url> --depth 3 --screenshots`
For dark mode: `npx designlang <url> --dark --screenshots`

2. **Read the generated markdown file** to understand the design:

```bash
cat design-extract-output/*-design-language.md
```

3. **Present key findings** to the user:
   - Primary color palette with hex codes
   - Font families in use
   - Spacing system (base unit if detected)
   - WCAG accessibility score
   - Component patterns found
   - Notable design decisions (shadows, radii, etc.)

4. **Offer next steps:**
   - Copy `*-tailwind.config.js` into their project
   - Import `*-variables.css` into their stylesheet
   - Paste `*-shadcn-theme.css` into globals.css for shadcn/ui users
   - Import `*-theme.js` for React/CSS-in-JS projects
   - Import `*-figma-variables.json` into Figma for designer handoff
   - Open `*-preview.html` in a browser for a visual overview
   - Use the markdown file as context for AI-assisted development

## Output Files (8)

| File | Purpose |
|------|---------|
| `*-design-language.md` | AI-optimized markdown — the full design system for LLMs |
| `*-preview.html` | Visual HTML report with swatches, type scale, shadows, a11y |
| `*-design-tokens.json` | W3C Design Tokens format |
| `*-tailwind.config.js` | Ready-to-use Tailwind CSS theme |
| `*-variables.css` | CSS custom properties |
| `*-figma-variables.json` | Figma Variables import format |
| `*-theme.js` | React/CSS-in-JS theme object |
| `*-shadcn-theme.css` | shadcn/ui theme CSS variables |

## Additional Commands

- **Compare two sites:** `npx designlang diff <urlA> <urlB>`
- **View history:** `npx designlang history <url>`

## Options

| Flag | Description |
|------|-------------|
| `--out <dir>` | Output directory (default: `./design-extract-output`) |
| `--dark` | Also extract dark mode color scheme |
| `--depth <n>` | Crawl N internal pages for site-wide extraction |
| `--screenshots` | Capture component screenshots (buttons, cards, nav) |
| `--wait <ms>` | Wait time after page load for SPAs |
| `--framework <type>` | Generate only specific theme (`react` or `shadcn`) |