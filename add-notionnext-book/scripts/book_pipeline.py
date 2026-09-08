#!/usr/bin/env python3
"""Discover source notes and validate a NotionNext Heo book import."""

from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from collections import Counter
from pathlib import Path
from urllib.parse import urlparse


CATALOG_PATH = Path("themes/heo/components/Book/bookCatalog.json")
KNOWLEDGE_PATH = Path("public/data/book-knowledge.json")
BOOK_COMPONENT_PATH = Path("themes/heo/components/Book/index.js")
ALLOWED_CATEGORIES = {
    "psychology",
    "growth",
    "literature",
    "business",
    "design",
    "feminism",
}


def configure_stdio() -> None:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")


def read_json(path: Path):
    with path.open("r", encoding="utf-8-sig") as handle:
        return json.load(handle)


def normalize_text(value: object) -> str:
    text = unicodedata.normalize("NFKC", str(value or "")).lower()
    return re.sub(r"[^0-9a-z\u4e00-\u9fff]+", "", text)


def title_keys(value: object) -> set[str]:
    text = unicodedata.normalize("NFKC", str(value or "")).strip()
    if not text:
        return set()
    keys = {normalize_text(text)}
    base = re.sub(
        r"[（(][^）)]*(?:版|edition)[^）)]*[）)]\s*$", "", text, flags=re.I
    ).strip()
    if base:
        keys.add(normalize_text(base))
    return {key for key in keys if key}


def parse_frontmatter(path: Path) -> tuple[dict[str, object], str]:
    text = path.read_text(encoding="utf-8-sig")
    lines = text.splitlines()
    metadata: dict[str, object] = {}
    body_start = 0

    if lines and lines[0].strip() == "---":
        for index, line in enumerate(lines[1:], start=1):
            if line.strip() == "---":
                body_start = index + 1
                break
            if ":" not in line or line.lstrip().startswith("#"):
                continue
            key, raw_value = line.split(":", 1)
            value = raw_value.strip()
            if value.startswith("[") and value.endswith("]"):
                metadata[key.strip()] = [
                    item.strip().strip("\"'")
                    for item in value[1:-1].split(",")
                    if item.strip()
                ]
            else:
                metadata[key.strip()] = value.strip("\"'")

    body = "\n".join(lines[body_start:])
    if not metadata.get("title"):
        heading = re.search(r"^#\s+(.+)$", body, flags=re.M)
        metadata["title"] = heading.group(1).strip() if heading else path.stem
    return metadata, body


def source_notes(source_root: Path) -> list[Path]:
    books_dir = source_root / "books"
    if not books_dir.is_dir():
        raise FileNotFoundError(f"Source books directory not found: {books_dir}")
    return sorted(books_dir.rglob("*.md"), key=lambda path: path.stat().st_mtime)


def catalog_title_keys(book: dict) -> set[str]:
    keys: set[str] = set()
    for field in ("title", "wereadTitle"):
        keys.update(title_keys(book.get(field)))
    return keys


def command_discover(args: argparse.Namespace) -> int:
    repo_root = Path(args.repo_root).resolve()
    source_root = Path(args.source_root).resolve()
    catalog = read_json(repo_root / CATALOG_PATH)
    books = catalog.get("books", [])
    rows = []

    for path in source_notes(source_root):
        metadata, _ = parse_frontmatter(path)
        keys = title_keys(metadata.get("title")) | title_keys(path.stem)
        matches = [
            book for book in books if keys and keys.intersection(catalog_title_keys(book))
        ]
        rows.append(
            {
                "status": "imported" if matches else "candidate",
                "title": metadata.get("title", path.stem),
                "author": metadata.get("author", ""),
                "source": str(path),
                "catalogIds": [book.get("id") for book in matches],
                "modifiedAt": path.stat().st_mtime,
            }
        )

    if args.json:
        print(json.dumps(rows, ensure_ascii=False, indent=2))
        return 0

    candidates = [row for row in rows if row["status"] == "candidate"]
    for row in rows:
        marker = "NEW" if row["status"] == "candidate" else "OK "
        matched = ", ".join(row["catalogIds"]) or "-"
        print(f"[{marker}] {row['title']} | {row['author']} | {matched}")
        print(f"      {row['source']}")
    print(f"\nFound {len(rows)} source note(s); {len(candidates)} unimported candidate(s).")
    return 0


class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []
        self.notes: list[str] = []

    def error(self, message: str) -> None:
        self.errors.append(message)

    def warn(self, message: str) -> None:
        self.warnings.append(message)

    def note(self, message: str) -> None:
        self.notes.append(message)

    def finish(self) -> int:
        for message in self.notes:
            print(f"[OK] {message}")
        for message in self.warnings:
            print(f"[WARN] {message}")
        for message in self.errors:
            print(f"[ERROR] {message}")
        print(
            f"\nValidation finished: {len(self.errors)} error(s), "
            f"{len(self.warnings)} warning(s)."
        )
        return 1 if self.errors else 0


def find_duplicates(values: list[str]) -> list[str]:
    return sorted(value for value, count in Counter(values).items() if count > 1)


def extract_array(source: str, constant_name: str) -> list[str] | None:
    match = re.search(
        rf"const\s+{re.escape(constant_name)}\s*=\s*\[(.*?)\]",
        source,
        flags=re.S,
    )
    if not match:
        return None
    return [single or double for single, double in re.findall(r"'([^']*)'|\"([^\"]*)\"", match.group(1))]


def is_weread_url(value: object) -> bool:
    if not isinstance(value, str) or not value:
        return False
    parsed = urlparse(value)
    return parsed.scheme == "https" and (
        parsed.hostname == "weread.qq.com"
        or bool(parsed.hostname and parsed.hostname.endswith(".weread.qq.com"))
    )


def validate_source(
    report: Report,
    source_root: Path,
    catalog_book: dict,
    explicit_source: str | None,
) -> None:
    if explicit_source:
        candidates = [Path(explicit_source).resolve()]
    else:
        candidates = source_notes(source_root)

    catalog_keys = catalog_title_keys(catalog_book)
    matched: list[tuple[Path, dict[str, object], str]] = []
    for path in candidates:
        if not path.is_file():
            report.error(f"Source note does not exist: {path}")
            continue
        metadata, body = parse_frontmatter(path)
        if catalog_keys.intersection(title_keys(metadata.get("title")) | title_keys(path.stem)):
            matched.append((path, metadata, body))

    if not matched:
        report.error("No source Markdown note matches the catalog title or wereadTitle.")
        return
    if len(matched) > 1:
        report.error(
            "Multiple source notes match this book: "
            + ", ".join(str(item[0]) for item in matched)
        )
        return

    path, metadata, body = matched[0]
    report.note(f"Source note matched: {path}")
    for field in ("title", "author", "tags", "date_ingested"):
        if not metadata.get(field):
            report.error(f"Source frontmatter is missing {field!r}.")
    source_author = normalize_text(metadata.get("author"))
    catalog_author = normalize_text(catalog_book.get("author"))
    if source_author and catalog_author and source_author != catalog_author:
        report.warn("Source and catalog author strings differ; verify edition metadata.")
    major_headings = re.findall(r"^##\s+(.+)$", body, flags=re.M)
    if len(major_headings) < 2:
        report.warn("Source note has fewer than two major ## sections; review content coverage manually.")
    else:
        report.note(f"Source note contains {len(major_headings)} major section(s).")


def command_validate(args: argparse.Namespace) -> int:
    report = Report()
    repo_root = Path(args.repo_root).resolve()
    source_root = Path(args.source_root).resolve()
    catalog_path = repo_root / CATALOG_PATH
    knowledge_path = repo_root / KNOWLEDGE_PATH
    component_path = repo_root / BOOK_COMPONENT_PATH

    for path in (catalog_path, knowledge_path, component_path):
        if not path.is_file():
            report.error(f"Required repository file is missing: {path}")
    if report.errors:
        return report.finish()

    catalog = read_json(catalog_path)
    knowledge = read_json(knowledge_path)
    catalog_books = catalog.get("books")
    knowledge_books = knowledge.get("books")
    edges = knowledge.get("edges")
    if not isinstance(catalog_books, list):
        report.error("Catalog books must be an array.")
        return report.finish()
    if not isinstance(knowledge_books, list) or not isinstance(edges, list):
        report.error("Knowledge books and edges must both be arrays.")
        return report.finish()

    catalog_ids = [book.get("id") for book in catalog_books if isinstance(book, dict)]
    knowledge_ids = [book.get("id") for book in knowledge_books if isinstance(book, dict)]
    for duplicate in find_duplicates([value for value in catalog_ids if value]):
        report.error(f"Duplicate catalog book ID: {duplicate}")
    for duplicate in find_duplicates([value for value in knowledge_ids if value]):
        report.error(f"Duplicate knowledge book ID: {duplicate}")
    if set(catalog_ids) != set(knowledge_ids):
        only_catalog = sorted(set(catalog_ids) - set(knowledge_ids))
        only_knowledge = sorted(set(knowledge_ids) - set(catalog_ids))
        report.error(
            f"Catalog/knowledge book IDs differ; catalog-only={only_catalog}, "
            f"knowledge-only={only_knowledge}."
        )
    else:
        report.note(f"Catalog and knowledge contain the same {len(set(catalog_ids))} book ID(s).")

    catalog_matches = [book for book in catalog_books if book.get("id") == args.book_id]
    knowledge_matches = [book for book in knowledge_books if book.get("id") == args.book_id]
    if len(catalog_matches) != 1:
        report.error(f"Expected exactly one catalog entry for {args.book_id!r}.")
    if len(knowledge_matches) != 1:
        report.error(f"Expected exactly one knowledge entry for {args.book_id!r}.")
    if len(catalog_matches) != 1 or len(knowledge_matches) != 1:
        return report.finish()

    catalog_book = catalog_matches[0]
    knowledge_book = knowledge_matches[0]
    required_catalog_strings = (
        "id",
        "title",
        "author",
        "category",
        "verdict",
        "highlights",
        "featuredInsight",
        "wereadSearchUrl",
        "wereadTitle",
        "cover",
    )
    for field in required_catalog_strings:
        if not isinstance(catalog_book.get(field), str) or not catalog_book[field].strip():
            report.error(f"Catalog field {field!r} must be a non-empty string.")
    if catalog_book.get("category") not in ALLOWED_CATEGORIES:
        report.error(f"Unsupported category: {catalog_book.get('category')!r}")
    if not isinstance(catalog_book.get("tags"), list) or not catalog_book.get("tags"):
        report.error("Catalog tags must be a non-empty array.")
    if not is_weread_url(catalog_book.get("wereadSearchUrl")):
        report.error("wereadSearchUrl must be an HTTPS weread.qq.com URL.")
    if catalog_book.get("wereadUrl") and not is_weread_url(catalog_book.get("wereadUrl")):
        report.error("wereadUrl must be an HTTPS weread.qq.com URL when present.")
    if not catalog_book.get("wereadUrl"):
        report.warn("No direct wereadUrl is present; only the search fallback will be used.")

    highlights = catalog_book.get("highlights", "")
    highlight_numbers = re.findall(r"（\d+）", highlights)
    if len(highlight_numbers) != 3:
        report.error("Catalog highlights must contain exactly three numbered highlights.")
    if highlights != knowledge_book.get("highlights"):
        report.error("Catalog and knowledge highlights are not identical.")

    cover = catalog_book.get("cover", "")
    if isinstance(cover, str) and cover.startswith("/"):
        cover_path = repo_root / "public" / cover.lstrip("/")
        if not cover_path.is_file():
            report.error(f"Cover file does not exist: {cover_path}")
        else:
            report.note(f"Cover exists: {cover_path}")
    else:
        report.error("Cover must be an absolute public path such as /images/books/book.jpg.")

    all_insights: list[dict] = []
    target_insights: list[dict] = []
    per_book_counts: dict[str, int] = {}
    for book in knowledge_books:
        book_id = book.get("id")
        chapters = book.get("chapters")
        if not isinstance(chapters, list) or not chapters:
            report.error(f"Knowledge book {book_id!r} has no chapters.")
            continue
        book_insights: list[dict] = []
        for chapter in chapters:
            chapter_name = chapter.get("chapterName") if isinstance(chapter, dict) else None
            insights = chapter.get("insights") if isinstance(chapter, dict) else None
            if not isinstance(chapter_name, str) or not chapter_name.strip():
                report.error(f"Knowledge book {book_id!r} has a chapter without a name.")
            if not isinstance(insights, list) or not insights:
                report.error(f"Chapter {chapter_name!r} in {book_id!r} has no insights.")
                continue
            for insight in insights:
                if not isinstance(insight, dict):
                    report.error(f"Chapter {chapter_name!r} contains a non-object insight.")
                    continue
                book_insights.append(insight)
                all_insights.append(insight)
                if book_id == args.book_id:
                    target_insights.append(insight)
        per_book_counts[book_id] = len(book_insights)

    insight_ids = [insight.get("id") for insight in all_insights if insight.get("id")]
    for duplicate in find_duplicates(insight_ids):
        report.error(f"Duplicate insight ID: {duplicate}")
    insight_id_set = set(insight_ids)
    for insight in target_insights:
        insight_id = insight.get("id", "<missing>")
        for field in ("id", "point", "explanation", "bookId"):
            if not isinstance(insight.get(field), str) or not insight[field].strip():
                report.error(f"Insight {insight_id!r} has an invalid {field!r} field.")
        if insight.get("bookId") != args.book_id:
            report.error(f"Insight {insight_id!r} has the wrong bookId.")
        if not isinstance(insight.get("keywords"), list) or not insight.get("keywords"):
            report.error(f"Insight {insight_id!r} must have at least one keyword.")

    catalog_by_id = {book.get("id"): book for book in catalog_books}
    for book_id, actual_count in per_book_counts.items():
        expected_count = catalog_by_id.get(book_id, {}).get("insightCount")
        if expected_count != actual_count:
            report.error(
                f"insightCount mismatch for {book_id!r}: catalog={expected_count}, "
                f"knowledge={actual_count}."
            )
    report.note(
        f"Target detail contains {len(knowledge_book.get('chapters', []))} chapter(s) "
        f"and {len(target_insights)} insight(s)."
    )

    touching_edges = 0
    target_insight_ids = {insight.get("id") for insight in target_insights}
    for index, edge in enumerate(edges):
        if not isinstance(edge, dict):
            report.error(f"Edge #{index + 1} is not an object.")
            continue
        source = edge.get("source")
        target = edge.get("target")
        if source not in insight_id_set:
            report.error(f"Edge #{index + 1} has missing source insight {source!r}.")
        if target not in insight_id_set:
            report.error(f"Edge #{index + 1} has missing target insight {target!r}.")
        for field in ("relation", "keyword"):
            if not isinstance(edge.get(field), str) or not edge[field].strip():
                report.error(f"Edge #{index + 1} has an invalid {field!r} field.")
        if source in target_insight_ids or target in target_insight_ids:
            touching_edges += 1
    if touching_edges == 0:
        report.warn("The target book has no cross-book edges.")
    else:
        report.note(f"Target book participates in {touching_edges} cross-book edge(s).")

    component_source = component_path.read_text(encoding="utf-8-sig")
    featured_ids = extract_array(component_source, "FEATURED_BOOK_IDS")
    featured_tones = extract_array(component_source, "FEATURED_TONES")
    if featured_ids is None:
        report.error("Could not parse FEATURED_BOOK_IDS.")
    else:
        for duplicate in find_duplicates(featured_ids):
            report.error(f"Duplicate featured book ID: {duplicate}")
        missing_featured = sorted(set(featured_ids) - set(catalog_ids))
        if missing_featured:
            report.error(f"Featured IDs are missing from the catalog: {missing_featured}")
        if featured_tones is not None and len(featured_ids) != len(featured_tones):
            report.error("FEATURED_BOOK_IDS and FEATURED_TONES have different lengths.")
        if args.expect_featured and args.book_id not in featured_ids:
            report.error(f"Target book {args.book_id!r} is not in FEATURED_BOOK_IDS.")
        if args.replaced_featured:
            if args.book_id not in featured_ids:
                report.error("Replacement target is not featured.")
            if args.replaced_featured in featured_ids:
                report.error(
                    f"Replaced book {args.replaced_featured!r} is still in FEATURED_BOOK_IDS."
                )
        report.note(f"Recommendation stack contains {len(featured_ids)} unique slot(s).")

    validate_source(report, source_root, catalog_book, args.source)
    return report.finish()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    discover = subparsers.add_parser("discover", help="List imported and new source notes.")
    discover.add_argument("--source-root", default=r"E:\knowledge-base")
    discover.add_argument("--repo-root", default=str(Path.cwd()))
    discover.add_argument("--json", action="store_true", help="Emit machine-readable JSON.")
    discover.set_defaults(func=command_discover)

    validate = subparsers.add_parser("validate", help="Validate one imported book and global invariants.")
    validate.add_argument("--source-root", default=r"E:\knowledge-base")
    validate.add_argument("--repo-root", default=str(Path.cwd()))
    validate.add_argument("--book-id", required=True)
    validate.add_argument("--source", help="Explicit source Markdown path.")
    validate.add_argument("--expect-featured", action="store_true")
    validate.add_argument("--replaced-featured")
    validate.set_defaults(func=command_validate)
    return parser


def main() -> int:
    configure_stdio()
    parser = build_parser()
    args = parser.parse_args()
    try:
        return args.func(args)
    except (OSError, json.JSONDecodeError) as error:
        print(f"[ERROR] {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
