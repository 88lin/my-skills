---
name: teach-impeccable
description: One-time setup that gathers design context for your project and saves it to your AI config file. Run once to establish persistent design guidelines.
user-invocable: true
---

Gather design context for this project, then persist it for all future sessions.

This standalone skill keeps the local split-skill workflow. It still writes `.impeccable.md` for compatibility with `/frontend-design`, but it should also capture the upstream Impeccable concepts that matter: register, strategic product context, anti-references, and accessibility needs.

## Step 1: Explore the Codebase

Before asking questions, thoroughly scan the project to discover what you can:

- **README and docs**: Project purpose, target audience, any stated goals
- **Package.json / config files**: Tech stack, dependencies, existing design libraries
- **Existing components**: Current design patterns, spacing, typography in use
- **Brand assets**: Logos, favicons, color values already defined
- **Design tokens / CSS variables**: Existing color palettes, font stacks, spacing scales
- **Any style guides or brand documentation**

Also form a **register hypothesis** from what you find:

- Brand signals: `/`, `/about`, `/pricing`, `/blog/*`, `/docs/*`, hero sections, big typography, scroll-driven sections, landing-page-shaped content.
- Product signals: `/app/*`, `/dashboard`, `/settings`, `/(auth)`, forms, data tables, side/top nav, app-shell components.

Register is a hypothesis at this point, not a decision. Confirm it with the user.

Note what you've learned and what remains unclear.

## Step 2: Ask UX-Focused Questions

Ask the user directly to clarify what you cannot infer. Focus only on what you couldn't infer from the codebase.

Use interview mode, not confirmation mode. If the repo is empty or the user's brief is sparse, ask 2-3 questions per round and wait for answers before drafting the context. Do not turn a one-sentence request into a complete inferred design context and ask for blanket confirmation.

### Register
- Should this primarily be treated as **brand** (marketing, landing, campaign, long-form content, portfolio; design is the product) or **product** (app UI, admin, dashboard, tool; design serves the product)?
- If the codebase suggests a clear register, lead with that hypothesis and ask the user to confirm or correct it.

### Users & Purpose
- Who uses this? What's their context when using it?
- What job are they trying to get done?
- For brand surfaces: what emotions should the interface evoke? (confidence, delight, calm, urgency, etc.)
- For product surfaces: what workflow are users in? What's the primary task on any given screen?

### Brand & Personality
- How would you describe the brand personality in 3 words?
- Any reference sites or apps that capture the right feel? What specifically about them?
- What should this explicitly NOT look like? Any anti-references?

For brand work, push for real-world references in the right lane (tech-minimal, editorial-magazine, consumer-warm, brutalist-grid, etc.), not generic "modern" adjectives. For product work, references to best-in-class tools are useful, but capture what pattern or feeling is relevant.

### Aesthetic Preferences
- Any strong preferences for visual direction? (minimal, bold, elegant, playful, technical, organic, etc.)
- Light mode, dark mode, or both?
- Any colors that must be used or avoided?

### Accessibility & Inclusion
- Specific accessibility requirements? (WCAG level, known user needs)
- Considerations for reduced motion, color blindness, or other accommodations?

Skip questions where the answer is already clear from the codebase exploration. Do not ask about detailed colors, fonts, or radii unless the user is explicitly setting a visual system now.

## Step 3: Write Design Context

Synthesize your findings and the user's answers into a `## Design Context` section:

```markdown
## Design Context

### Register
[brand or product, plus any per-surface nuance]

### Users
[Who they are, their context, the job to be done]

### Product Purpose
[What this product does, why it exists, what success looks like]

### Brand Personality
[Voice, tone, 3-word personality, emotional goals]

### Aesthetic Direction
[Visual tone, references, anti-references, theme]

### Anti-References
[What this should not look like: specific sites, categories, or patterns to avoid]

### Design Principles
[3-5 strategic principles derived from the conversation. Prefer principles like "practice what you preach", "show, don't tell", "expert confidence" over implementation rules like "use OKLCH".]

### Accessibility & Inclusion
[WCAG level, known user needs, reduced motion, color blindness, or other accommodations]
```

Write this section to `.impeccable.md` in the project root. If the file already exists, update the Design Context section in place.

Then ask the user directly to clarify what you cannot infer. whether they'd also like the Design Context appended to .github/copilot-instructions.md. If yes, append or update the section there as well.

Confirm completion and summarize the key design principles that will now guide all future work.
