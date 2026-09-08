---
name: add-notionnext-book
description: Import finished-book Markdown notes from E:\knowledge-base into the NotionNext Heo /book reading shelf. Use when the user asks to add, sync, update, or feature a newly read book and expects the catalog card, complete chapter-and-insight detail, cross-book connections, cover, WeChat Read link, recommendation stack, and derived statistics to stay consistent.
---

# Add a NotionNext Book

Add a finished book without dropping source-note content or leaving the shelf and detail data out of sync.

## Fixed locations

- Source notes: `E:\knowledge-base\books\*.md`
- Source index: `E:\knowledge-base\_index.md`
- Repository: `C:\Users\Computer\Documents\GitHub\NotionNext`
- Catalog: `themes/heo/components/Book/bookCatalog.json`
- Full notes: `public/data/book-knowledge.json`
- Recommendation IDs: `themes/heo/components/Book/index.js`
- Covers: `public/images/books/`

Honor user-supplied path overrides. Keep changes inside the Heo `/book` surface and required book assets. Preserve unrelated staged and unstaged work; do not stage, commit, reset, or clean unless explicitly requested.

## Workflow

1. Discover source books before editing:

   ```powershell
   $env:PYTHONUTF8='1'
   python "C:\Users\Computer\.agents\skills\add-notionnext-book\scripts\book_pipeline.py" discover --source-root "E:\knowledge-base" --repo-root "C:\Users\Computer\Documents\GitHub\NotionNext"
   ```

2. Select the user-named book, or the newest unimported candidate when the request says only “新增的书”. Read that Markdown file completely, including frontmatter, every `##` section, actionable points, and quotations. Read [book-data-contract.md](references/book-data-contract.md) before constructing data.

3. Inspect `git status`, the current target files, the existing category vocabulary, and several nearby book entries. Never replace the accepted UI or regenerate unrelated books.

4. Resolve external metadata carefully:

   - Verify the exact WeChat Read reader URL on `weread.qq.com`; never invent a reader ID.
   - Always provide an encoded WeChat Read search URL as a fallback.
   - Obtain a real cover matching the same edition when possible. Do not use generated artwork as a book cover or retain unused downloads.
   - If exact metadata cannot be verified, stop and report that specific gap instead of fabricating it.

5. Add one catalog object and one knowledge-book object with the same stable ASCII kebab-case ID. Update both `generatedAt` fields. Let `pages/book.js` derive total book, chapter, and insight statistics; do not add hardcoded totals.

6. Preserve the note's substance:

   - Cover every major source section in a highlight, chapter, or insight. Do not shorten content merely to avoid scrolling; the detail panel is designed to scroll.
   - Write enough thematic chapters and insights to preserve the source, rather than targeting a fixed count. A typical full note produces 4-8 chapters and 12-30 insights.
   - Give every insight a unique ID, clear claim, explanation, concrete example when supported, the matching `bookId`, and 1-3 reusable topic keywords.
   - Use exactly three numbered highlights in the existing `（1）...；（2）...；（3）...` form and keep them identical in both JSON files.
   - Paraphrase notes faithfully. Never invent quotations, claims, page numbers, personal reactions, or reading history.

7. Add 3-6 meaningful cross-book edges when suitable. Link only existing insight IDs, describe the actual relationship, and prefer topic keywords already used by one of the connected insights. Do not create decorative or weak connections merely to reach a count.

8. Change `FEATURED_BOOK_IDS` only when the user explicitly requests recommendation placement or replacement. Replace the named book in place, keep the stack length stable unless requested otherwise, and prevent duplicate IDs. Do not remove the replaced book from the main catalog.

9. Format and validate:

   ```powershell
   npx prettier --write themes/heo/components/Book/bookCatalog.json public/data/book-knowledge.json themes/heo/components/Book/index.js
   $env:PYTHONUTF8='1'
   python "C:\Users\Computer\.agents\skills\add-notionnext-book\scripts\book_pipeline.py" validate --repo-root "C:\Users\Computer\Documents\GitHub\NotionNext" --source-root "E:\knowledge-base" --book-id "BOOK_ID"
   npx eslint pages/book.js themes/heo/components/Book/index.js themes/heo/index.js
   yarn type-check
   git diff --check
   ```

   Add `--expect-featured` when recommendation placement was requested. Add `--replaced-featured OLD_ID` when a specific recommendation was replaced.

10. Review the final diff and report the source file, new book ID, category, chapter/insight/edge counts, recommendation change, cover path, WeChat Read URL, and validation results. State any unverified external metadata explicitly.

## Guardrails

- Treat the Markdown note as the content authority and the current JSON/UI schema as the integration authority.
- Do not overwrite the source knowledge base.
- Do not silently import every candidate when the user requested one book.
- Do not leave a catalog-only book, a knowledge-only book, mismatched highlights, dangling edges, duplicate insight IDs, or an incorrect `insightCount`.
- Do not delete `.impeccable`, `PRODUCT.md`, `DESIGN.md`, existing covers, or unrelated artifacts.
- Skip browser screenshots unless requested or a runtime interaction changed; data-only additions need deterministic validation and targeted static checks.

