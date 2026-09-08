# Heo Book Data Contract

## Files and ownership

| File | Required change |
| --- | --- |
| `themes/heo/components/Book/bookCatalog.json` | Add the shelf/card metadata object. |
| `public/data/book-knowledge.json` | Add complete chapters and insights; add valid cross-book edges. |
| `themes/heo/components/Book/index.js` | Change `FEATURED_BOOK_IDS` only on explicit request. |
| `public/images/books/<book-id>.<ext>` | Add one verified cover used by the catalog object. |

Both JSON files have a top-level `generatedAt` date. `book-knowledge.json` also retains its existing `version` value.

## Catalog object

```json
{
  "id": "stable-ascii-slug",
  "title": "用于卡片的简洁书名",
  "author": "作者",
  "category": "growth",
  "verdict": "适合谁、解决什么问题，以及必要的判断边界。",
  "highlights": "（1）高光一；（2）高光二；（3）高光三。",
  "tags": ["标签一", "标签二", "标签三"],
  "insightCount": 17,
  "featuredInsight": "适合推荐叠卡的一条核心判断",
  "wereadUrl": "https://weread.qq.com/web/reader/VERIFIED_ID",
  "wereadSearchUrl": "https://weread.qq.com/web/search/books?keyword=ENCODED_TITLE",
  "wereadTitle": "微信读书中的准确书名",
  "cover": "/images/books/stable-ascii-slug.jpg"
}
```

Allowed categories:

- `psychology`: 心理学、关系、情绪与心理治疗
- `growth`: 思维方法、自我成长、习惯与人生策略
- `literature`: 小说、散文与文学作品
- `business`: 商业、产品、投资、传播与管理
- `design`: 设计、建筑、创作与用户体验
- `feminism`: 女性主义、性别研究与女性处境

Choose the closest existing category. Do not create a category without an explicit UI change request.

`matchScore` and `matchType` are legacy acquisition metadata. Preserve them on existing books; add them only when their values come from a real matching process.

## Knowledge-book object

```json
{
  "id": "same-id-as-catalog",
  "highlights": "exactly the same three highlights",
  "chapters": [
    {
      "chapterName": "第一章：主题名称",
      "insights": [
        {
          "id": "globally-unique-insight-id",
          "point": "可独立理解的核心判断",
          "explanation": "说明逻辑、条件与边界，而不是重复 point。",
          "example": "源笔记支持时，给出具体生活或工作场景。",
          "bookId": "same-id-as-catalog",
          "keywords": ["可复用主题", "另一个主题"]
        }
      ]
    }
  ]
}
```

Do not copy the source Markdown headings mechanically. Group related material into readable thematic chapters while retaining coverage of every major `##` section. Keep examples faithful to the source principles; omit `example` when a concrete example would require invention.

## Cross-book edge

```json
{
  "source": "existing-insight-id",
  "target": "new-or-existing-insight-id",
  "relation": "一句话说明两条观点如何互补、冲突、因果相连或提供边界",
  "keyword": "简洁主题"
}
```

Use only insight IDs that exist after the edit. Prefer relations a reader can understand without opening both books. Avoid linking two ideas solely because they share a broad word such as“成长”或“人生”.

## Content quality checks

- Derive author and source tags from YAML frontmatter; use the note body for all interpretations.
- Keep three highlights selective and non-overlapping.
- Make `featuredInsight` a real judgment from the note, not a marketing slogan.
- Make `verdict` useful: describe the book's method, audience, and limitation or emphasis.
- Keep topic keywords reusable across books. Prefer existing terms such as `批判性思维`, `系统思维`, `自我觉察`, `成长心态`, or `真诚沟通` when accurate.
- Set `insightCount` to the actual flattened insight count.
- Keep catalog and knowledge ID sets identical.
- Keep recommendation IDs unique and backed by catalog entries.

