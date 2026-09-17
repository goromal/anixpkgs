# anix-llm

`anix-llm` is the unified local-LLM client for `personal-dell`. It talks to one
loopback-only Ollama system service and uses that service's single model cache.

## Commands

```console
# Check the service and installed model.
anix-llm status

# Print a normal text response. Omitting the argument prompts without shell history.
anix-llm ask
printf '%s\n' 'Explain this design.' | anix-llm ask --context ./project

# Give directory context and write files in one request.
anix-llm write \
  --context ./project \
  --include '*.py' \
  --output-dir ./generated \
  'Create architecture.md and a concise README.md.'

# Keep a multi-turn conversation in process memory only.
anix-llm chat --context ./project

# Ensure the configured model exists without downloading a duplicate.
anix-llm ensure

# Open service logs, chat, ask, and write in four tmux panes.
anix-llm workspace --context ./project --output-dir ./generated
```

Global overrides precede the command:

```console
anix-llm --model qwen3.5:27b --url http://127.0.0.1:11434 ask
```

## Directory context

`--context` and `--context-dir` are aliases and may be repeated. Context is sent
in the same request as the task, so reading a directory and producing files does
not require two CLI calls. By default the client:

- skips symlinks, binary files, hidden files, common build trees, and common secret files;
- sends at most 200 files and 60,000 UTF-8 bytes;
- accepts repeated `--include` globs to narrow the input;
- treats file contents as untrusted reference data rather than instructions.

Use the `--max-context-*` flags to adjust the bounds. Review sensitive source
trees before using `--include-hidden`.

## File writes

The model returns a schema-constrained text-file manifest. The client rejects
absolute paths, parent traversal, symlink escapes, duplicate paths, binary
content, excessive output, and overwrites unless `--overwrite` is supplied. It
shows the proposed paths and asks for confirmation unless `--yes` is supplied.

## Persistence

- Ollama model blobs persist once in `/var/lib/ollama/models`.
- `ask`, `write`, and `chat` send requests directly to the local API and do not create chat-history files.
- `chat` history exists only in the client process and disappears on exit or `/clear`.
- Ollama request-body debug logging is disabled, and the server only listens on loopback.
- Files approved through `write` are intentionally persisted beneath `--output-dir`.

A prompt supplied as a shell argument can still enter shell history. Omit the
prompt for an interactive prompt, or pipe it on standard input, when that matters.
