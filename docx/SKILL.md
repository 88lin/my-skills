---
name: docx
description: >-
  Use this skill when a Word document (.docx) is the explicit input or the most likely required output. Good fit for creating, reading, editing, restructuring, or polishing .docx files. In Codex, prefer an available first-party document artifact skill; use this local skill when explicitly requested, as a fallback, or in clients without that capability. Do not trigger for prose drafting alone when no Word file is required.
license: Proprietary. LICENSE.txt has complete terms
---

<!-- LOCAL ROUTING OVERRIDE START -->
## Usage Rule

Use this skill when the format requirement is clearly **Word / .docx**, whether stated explicitly or strongly implied by the deliverable.

Trigger it when the task clearly involves one of these goals:

- Reading or modifying an existing `.docx`
- Producing a `.docx` file as the final deliverable
- Reformatting, restructuring, or polishing a Word document
- Working with tracked changes, comments, images, headers, footers, or table of contents inside a Word file

The user does **not** need to literally say `.docx`. If they clearly want a formal Word-style deliverable that someone will continue editing in Microsoft Word, this skill can be the right match.

Do **not** use this as the default for every "write a report" style request.

- If the user only wants help drafting text, planning structure, or improving prose, use a writing or documentation workflow first
- If the user explicitly wants a PDF deliverable, prefer `pdf`
- If the user explicitly wants a spreadsheet deliverable, prefer `xlsx`
- If the user explicitly wants a presentation deliverable, prefer `pptx` or `html-ppt` depending on format (the external `ppt-master` workflow can also generate a new PPTX from this DOCX, but it runs manually outside the skill system)
<!-- LOCAL ROUTING OVERRIDE END -->

# DOCX creation, editing, and analysis

A `.docx` is a ZIP archive of XML files. Choose your approach by task:

| Task | Approach |
|---|---|
| **Create** a new document | Write a `docx` (npm) script — see gotchas below |
| **Edit** an existing document | `unzip` → edit `word/document.xml` → `zip` (docx-js cannot open existing files) |
| **Read** content | `pandoc -t markdown file.docx` |

> Script paths below are relative to this skill's directory.

## Creating with docx-js — gotchas

`docx` is preinstalled — do not run `npm install` first; write the script and `require('docx')` directly. Only if that require fails: `npm install docx`. The model knows the API; these are the footguns:

- **Page size defaults to A4.** For US Letter set `page: { size: { width: 12240, height: 15840 } }` (DXA; 1440 = 1″).
- **Landscape:** pass portrait dimensions and `orientation: PageOrientation.LANDSCAPE` — docx-js swaps width/height internally.
- **Tables need dual widths:** set `columnWidths` on the table AND `width` on every cell, both in `WidthType.DXA` (PERCENTAGE breaks in Google Docs). Column widths must sum to the table width.
- **Table shading:** use `ShadingType.CLEAR`, never `SOLID` (renders black).
- **Lists:** never insert `•` literally; use a `numbering` config with `LevelFormat.BULLET`.
- **`ImageRun` requires `type:`** (`"png"`, `"jpg"`, …).
- **`PageBreak` must be inside a `Paragraph`.**
- **Never use `\n`** — use separate `Paragraph` elements.
- **TOC:** headings must use built-in `HeadingLevel.*`; custom heading styles need `outlineLevel` set or they won't appear.
- **Don't use a table as a horizontal rule** — use a paragraph bottom border instead.
- **Dot-leader / right-aligned-on-same-line:** use `PositionalTab` (`alignment: PositionalTabAlignment.RIGHT`, `leader: PositionalTabLeader.DOT`) inside a `TextRun`, not literal `.` or space padding.

## Verify the output

After writing a `.docx`, render it and look at it:

```bash
python scripts/office/soffice.py --headless --convert-to pdf output.docx
pdftoppm -jpeg -r 100 output.pdf page
ls page-*.jpg   # then Read the images
```

`pdftoppm` zero-pads page numbers to the width of the page count (`page-01.jpg`…`page-12.jpg`).

## Editing existing documents

Legacy `.doc` files must be converted first: `python scripts/office/soffice.py --headless --convert-to docx file.doc`.

```bash
unzip -q doc.docx -d unpacked/
find unpacked -type l -delete   # strip symlink entries — docx from external parties is untrusted
python scripts/merge_runs.py unpacked/   # coalesce fragmented runs so text is findable
# edit unpacked/word/document.xml in place — do NOT reformat or pretty-print
(cd unpacked && rm -f ../out.docx && zip -Xr ../out.docx .)
python scripts/office/validate.py out.docx --original doc.docx   # XSD checks; --auto-repair fixes common issues
# redlining? add --author "<the name you redlined under>" to check every edit is tracked
```

Word splits text across many `<w:r>` runs (revision ids, spell-check markers), so a phrase you can see in the document often doesn't exist as a contiguous string in the XML. `merge_runs.py` merges adjacent identically-formatted runs in `word/document.xml` without changing content or rendering; it also accepts a `.docx` directly (`python scripts/merge_runs.py doc.docx -o merged.docx`).

**Tracked changes:** when redlining, validate with `--author "<the name you redlined under>"` (needs `--original`) — it reports any text you changed without a `<w:ins>`/`<w:del>` around it, which is easy to do by accident and invisible in the accepted view. Wrap runs in `<w:ins>`/`<w:del>` with `w:id`, `w:author`, `w:date` attributes. Inside `<w:del>`, the text element is `<w:delText>`, not `<w:t>`. A deleted paragraph mark (`<w:pPr><w:rPr><w:del w:id=".." w:author=".." w:date=".."/></w:rPr></w:pPr>`) means "merge this paragraph into the next" — so deleting a paragraph outright is that plus a `<w:del>` around every run. The `<w:del/>` must come before the rPr's other children; their order is schema-enforced.

To produce a clean copy with all tracked changes accepted: `python scripts/accept_changes.py in.docx out.docx`.

Accepting a deleted paragraph mark should join that paragraph to the one below it, so a paragraph whose runs are *all* deleted vanishes. Word does this; `accept_changes.py` and `pandoc --track-changes=accept` don't always. Both fail the same way — they strip the deleted text but leave the emptied paragraph behind, which reads as a stray empty bullet when it was auto-numbered:

- `pandoc --track-changes=accept` never joins the paragraphs.
- `accept_changes.py` (LibreOffice) joins them correctly, except when the deleted paragraph is followed by an empty spacer paragraph.

An empty bullet in either view is an artifact of that view, not a defect in the document. Check paragraph deletions in the XML.

## Comments

Comments require six cross-linked files. Use the helper — directory mode when you'll also be editing `document.xml` (saves an unzip/rezip cycle), `.docx`-direct mode otherwise:

```bash
# Against an already-unpacked directory (preferred when also placing markers)
python scripts/comment.py unpacked/ "Fees & expenses cap is too low"
python scripts/comment.py unpacked/ "Agreed" --parent 0

# Against a .docx directly
python scripts/comment.py contract.docx "This cap is too low" -o annotated.docx
```

The script writes `comments.xml`, `commentsExtended.xml`, `commentsIds.xml`, `commentsExtensible.xml`, the relationships, and the content-type overrides. Comment IDs are auto-assigned. It then prints the `<w:commentRangeStart>`/`<w:commentRangeEnd>`/`<w:commentReference>` snippet to add to `word/document.xml` so the comment anchors to specific text — until you place those markers, the comment exists but is not visible.

## Dependencies

`docx` (npm, preinstalled — install only if `require('docx')` fails) · `pandoc` · LibreOffice (`soffice`) · `pdftoppm` (Poppler)
