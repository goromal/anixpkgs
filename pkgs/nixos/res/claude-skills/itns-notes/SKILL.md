---
name: itns-notes
description: Use when organizing, sorting, or adding notes in the ITNS namespace in Notion. ITNS notes must be handled as bulleted lists only.
---

When organizing or adding notes in the **ITNS namespace** in Notion, render every note as a **flat bulleted list — bullets only**. Do not use headings, tables, paragraphs, code blocks, or any other block type for ITNS notes.

**How:** use the Notion MCP `notion_append` tool with `format: "bullets"` (each input line becomes one bullet). Do **not** use the default Markdown conversion for ITNS content.

**Why:** the ITNS page-sorting workflow is built around flat bulleted lists — `notion_list_blocks` + `notion_move_block` operate on individual bullets. Other block types break how notes are sorted and moved.

**Scope:** this rule applies only to the ITNS namespace. Elsewhere in Notion, the Markdown-aware default of `notion_append` is fine.
