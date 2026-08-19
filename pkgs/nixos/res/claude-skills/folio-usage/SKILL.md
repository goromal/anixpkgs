---
name: folio-usage
description: Use when reading, searching, highlighting, tagging, or annotating books in the folio app via the folio MCP tools (mcp__folio__*). Covers the book/chapter/block model and the highlight → tag → note workflow, including the non-obvious text→block mapping step.
---

folio is a personal reading app. The `mcp__folio__folio_*` tools let you read a book's text, locate passages, and attach highlights, tags, and notes that show up in the user's live reader.

## Data model

- **book → chapter → block.** A *block* is one paragraph of prose (a quoted extract is its own block).
- Highlights, tags, and notes never attach to raw text — they attach to a **passage**, which is a span defined by `(start_block, start_off) → (end_block, end_off)`.
- To highlight a whole paragraph, make a passage over a single block with `start_off = 0` and a large `end_off` (see below).

## Orientation

```
folio_list_books                      # -> [{id, title, author}]
folio_get_toc(book_id)                # -> chapters; titles are filenames, the real
                                      #    title is the first line of the chapter text
folio_goto(block_id | passage_id)     # move the user's live reader view
```

## Reading text

`folio_get_section_text(book_id[, chapter_id])` returns plain text **with no block IDs**.

- The payload is a JSON string with escaped newlines. Decode it, then split on `\n\n` to get paragraphs.
- A whole-book pull (`book_id` only) is ~1 MB and will overflow the tool result to a file. **Do not read it into context** — `grep`/slice it on disk. Splitting into paragraphs and matching keyword sets is a cheap way to survey the entire book.
- Quoted extracts appear **2–3 times consecutively** in the text (an ingestion quirk — see Gotchas).

## Mapping text → block_id (the key step)

`folio_get_section_text` gives you *what* to highlight but not *where*. Two ways to get the `block_id`:

```
folio_get_blocks(book_id[, chapter_id])   # -> [{id, chapter_id, text, ...}] WITH ids
folio_search(book_id, query, limit)       # -> ranked [{block_id, chapter_id, snippet}]
```

- `folio_get_blocks` is the direct route — same text as `get_section_text` but each block carries its `id`. Match your target paragraph to a block and take its `id`.
- `folio_search` is faster when you already know a distinctive word. It is **FTS5 with AND semantics**: multi-word natural-language queries almost always return `[]`, so use **single distinctive keywords** (or a few words you know co-occur in the same paragraph).
- Either way, quoted extracts appear as **duplicate blocks** (2–3 identical consecutive ids). Use the **lowest** id.
- A search snippet is enough to confirm the right block; for argument/context judgement, grep the on-disk section text instead.

## Highlight / tag / note recipe

```
p = folio_create_passage(book_id, start_block=B, start_off=0, end_block=B, end_off=20000)
folio_add_highlight(passage_id=p.id, color="yellow")   # palette: yellow, green, blue, pink, red
folio_add_tag(passage_id=p.id, name="SomeTag")
folio_add_note(passage_id=p.id, body="...")            # note attaches to exactly one of
                                                       # passage_id | chapter_id | book_id
```

- `end_off` past the end of the block **clamps to the block end**, so a large constant (e.g. `20000`) reliably selects "the whole paragraph." Because `start_block == end_block`, the highlight can never bleed into a neighbouring block.
- Do the `create_passage` calls first (they return the ids), then batch the highlight/tag/note calls.

## Gotchas

- **`folio_get_passage` does NOT return resolved text** — only anchors plus attached `highlights`/`tags`/`notes`. Verify a highlight landed by checking those fields, not the text.
- **Cleanup exists but is coarse.** `folio_delete_passage` removes a passage and its highlights/tags/notes; `folio_delete_highlight`, `folio_delete_tag`, and `folio_delete_note` remove individual items. Still, prefer not to create throwaway/test passages against real content.
- **Block duplication is upstream data, not a search bug.** Picking the lowest of the duplicate `block_id`s highlights the copy the reader sees first.
