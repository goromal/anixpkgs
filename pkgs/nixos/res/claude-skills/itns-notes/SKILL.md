---
name: itns-notes
description: Integrate, sort, organize, or funnel ITNS ("Integrate These Notes Somewhere") notes from a named Notion page into appropriate subpages. Use when the user mentions ITNS, asks to process a Notion notes repository, or names a page whose loose notes should be filed. Resolve page names through ~/configs/goromail-categories.csv, move obvious notes automatically, and require the user's decision for every ambiguous placement or new subpage.
---

# Process ITNS notes

Use the installed Notion MCP server. Preserve each note's wording, formatting, links,
dates, priority markers, block types, order, and nested children. Do not summarize,
rewrite, split, merge, deduplicate, or delete content unless the user explicitly asks.

## Resolve the source page

1. Match the user-provided page name exactly and case-insensitively against the first
   column of `~/configs/goromail-categories.csv`.
2. Use the corresponding second-column Notion page ID.
3. Stop and ask if there is no exact match or more than one exact match. Never guess
   an ID from a similar name.

## Discover notes and destinations

1. Call `notion_list_subpages` on the source page to collect candidate destinations.
2. Call `notion_list_blocks` with `recursive: true` on the source page. Treat a parent
   block and all descendants as one indivisible note tree.
3. Treat adjacent top-level paragraphs, list items, code blocks, and other prose as one
   compound note when their content clearly forms a continuous thought. If its boundary
   is uncertain, classify the boundary as ambiguous and ask the user.
4. Exclude headings, child-page blocks, page-mention links, and other navigation or
   structural blocks. When a `Repository` heading exists, use the loose content after it
   as the source-note region. If no reliable source-note boundary exists, ask before
   moving anything.
5. Inspect relevant destination contents with recursive block listing. Classify from
   both the destination title and its existing subject matter, not its title alone.
6. For an opaque link or vague label, inspect the linked material when access is
   available. Ask rather than infer when its subject remains unclear.

## Decide automatically or ask

Move a note automatically only when all of these are true:

- exactly one existing subpage is a strong semantic fit;
- the complete note and its boundaries are understood;
- the move requires no rewriting, splitting, merging, or category invention.

Treat every other case as ambiguous. Present the complete note or a faithful compact
preview, the plausible destinations, and one recommendation with a short reason. Wait
for the user's decision before writing that note. Always ask before creating or naming a
new subpage.

Continue processing independent obvious notes while ambiguous notes await a decision.
Do not let an obvious placement silently decide a related ambiguous placement.

## Execute and verify moves

- Move one top-level note tree with `notion_move_block`; its descendants move with it.
- Move a compound note made of adjacent top-level blocks with `notion_move_blocks`.
  Pass block IDs once, in their original order, to one destination.
- Create a user-approved category with `notion_create_subpage`, then move only the notes
  approved for it.
- Never emulate a move with lossy text append plus deletion.
- After each batch, list the source and destination again. Verify that every source block
  is absent, every destination block is present in order, child counts match, and block
  types and text are preserved.
- If any operation partially fails, stop further writes, inspect both pages, and report
  the exact copied, archived, remaining, or duplicated blocks before attempting repair.
- If recursive listing or ordered batch moves are unavailable, stop and report that the
  Notion MCP server must be deployed or upgraded before compound notes can be processed
  safely.

Finish with a concise record of automatic moves, user-approved moves, created pages,
deferred ambiguities, and verification results.
